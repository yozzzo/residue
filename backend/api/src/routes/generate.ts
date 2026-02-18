import type { Env } from '../types/env';

// Condition key normalization
export function buildConditionKey(
  worldId: string,
  nodeId: string,
  truthStage: number,
  topTrait: string,
  flags: string[]
): string {
  const sortedFlags = flags.slice(0, 3).sort().join(',');
  return `${worldId}:${nodeId}:ts${truthStage}:t_${topTrait || 'none'}:f_${sortedFlags}`;
}

// LLM call via Workers AI
async function callWorkersAI(env: Env, prompt: string): Promise<string> {
  try {
    const response = await env.AI.run('@cf/meta/llama-3.1-70b-instruct', {
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 1024,
      temperature: 0.8,
    });
    return response.response || '';
  } catch (e: any) {
    console.error('Workers AI error:', e.message);
    throw new Error('LLM generation failed');
  }
}

// Plot agent prompt
function buildPlotPrompt(params: {
  worldId: string;
  nodeId: string;
  nodeName: string;
  nodeDescription: string;
  truthStage: number;
  loopCount: number;
  traits: string[];
  playStyle: string;
  flags: string[];
}): string {
  const curveInstruction = params.loopCount <= 2
    ? '初回〜2周目: 世界観紹介、基本的な脅威と選択'
    : params.loopCount <= 5
    ? '3〜5周目: 前周回の痕跡が現れ始める、選択に重みが増す'
    : '6周目以降: 真実への手がかり、メタ的な違和感、重要な分岐';

  return `あなたはダークファンタジーローグライク「Residue」のストーリーディレクターです。

【世界設定】
死んでもループする世界。前の周回の痕跡（残痕/Residue）が消し残りとして蓄積される。
プレイヤーは繰り返しの中で真実に近づいていく。

【現在の状況】
- 世界: ${params.worldId}
- 場所: ${params.nodeName} (${params.nodeDescription})
- プレイヤー: 周回${params.loopCount}回目、真実段階${params.truthStage}
- 性格傾向: ${params.traits.join(', ') || 'なし'}
- プレイスタイル: ${params.playStyle || '不明'}
- 既知フラグ: ${params.flags.join(', ') || 'なし'}

【制約】
- テキストは2-3行、短く鋭く
- 選択肢は2-4個、状況に合った具体的な行動
- 周回体験カーブ: ${curveInstruction}
- Residueの核: 死と継承、消し残り、前周回の痕跡

このノードで起きるイベントのプロットを1段落で書いてください。
何が起き、プレイヤーにどんな選択を迫り、どんな結果になるか。`;
}

// Writer agent prompt
function buildWriterPrompt(plot: string): string {
  return `以下のプロットをゲームイベントJSON形式に変換してください。

【プロット】
${plot}

【出力形式】必ず以下のJSON形式のみを出力してください。説明文は不要です。
{
  "text_ja": "イベントテキスト（2-3行）",
  "choices": [
    {
      "label": "選択肢テキスト",
      "tags": ["trait_tag1"],
      "effect": {"type": "damage", "value": 10},
      "result_text": "結果テキスト（1行）",
      "sets_flag": null
    }
  ]
}

【制約】
- 選択肢labelは具体的な行動（「祭壇を調べる」のように）
- effectのtypeはdamage/heal/goldのいずれか、valueは5-20
- tagsは以下から選択: merciful, cruel, curious, cautious, bold, reckless, fearless, defiant, obedient, pragmatic, empathetic, thorough, hasty, greedy
- sets_flagはsnake_case、動的に新しいフラグ名を作ってよい（またはnull）
- JSONのみ出力すること`;
}

// Review agent prompt
function buildReviewPrompt(eventJson: string): string {
  return `以下のゲームイベントJSONを品質レビューしてください。

${eventJson}

以下の基準で0.0〜1.0のスコアと短いフィードバックをJSON形式で返してください：
- テキストの雰囲気（ダークファンタジーらしいか）
- 選択肢の具体性（曖昧でないか）
- 効果値の妥当性（5-20範囲内か）
- タグの適切さ

{"quality_score": 0.8, "feedback": "..."}

JSONのみ出力すること。`;
}

// Parse JSON from LLM output (may have surrounding text)
function extractJson(text: string): any {
  // Try direct parse first
  try { return JSON.parse(text.trim()); } catch {}
  // Find JSON block
  const match = text.match(/\{[\s\S]*\}/);
  if (match) {
    try { return JSON.parse(match[0]); } catch {}
  }
  return null;
}

// Generate a UUID-like ID
function generateId(): string {
  return 'ge_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
}

// Main generation pipeline
export async function generateEvent(
  env: Env,
  params: {
    worldId: string;
    nodeId: string;
    nodeName: string;
    nodeDescription: string;
    truthStage: number;
    loopCount: number;
    traits: string[];
    playStyle: string;
    flags: string[];
    conditionKey: string;
  },
  retries = 0
): Promise<any> {
  // Step 1: Plot
  const plotPrompt = buildPlotPrompt(params);
  const plot = await callWorkersAI(env, plotPrompt);

  // Step 2: Writer
  const writerPrompt = buildWriterPrompt(plot);
  const writerOutput = await callWorkersAI(env, writerPrompt);
  const event = extractJson(writerOutput);

  if (!event || !event.text_ja || !event.choices) {
    if (retries < 2) {
      return generateEvent(env, params, retries + 1);
    }
    throw new Error('Failed to generate valid event after retries');
  }

  // Step 3: Review
  const reviewPrompt = buildReviewPrompt(JSON.stringify(event));
  const reviewOutput = await callWorkersAI(env, reviewPrompt);
  const review = extractJson(reviewOutput) || { quality_score: 0.7, feedback: '' };

  if (review.quality_score < 0.6 && retries < 2) {
    return generateEvent(env, params, retries + 1);
  }

  // Save to DB
  const genEventId = generateId();
  await env.DB.prepare(
    `INSERT INTO generated_events (gen_event_id, world_id, node_id, condition_key, layer, text_ja, choices_json, effects_json, generated_by, quality_score, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    genEventId,
    params.worldId,
    params.nodeId,
    params.conditionKey,
    'L2_detail',
    event.text_ja,
    JSON.stringify(event.choices || []),
    JSON.stringify(event.effects || null),
    'workers_ai',
    review.quality_score,
    'active'
  ).run();

  return {
    gen_event_id: genEventId,
    text_ja: event.text_ja,
    choices: event.choices,
    quality_score: review.quality_score,
    generated_by: 'workers_ai',
  };
}
