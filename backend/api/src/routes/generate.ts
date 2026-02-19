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

// --- Gemini API ---

async function callGemini(apiKey: string, prompt: string, systemPrompt?: string): Promise<string> {
  const contents: any[] = [];
  if (systemPrompt) {
    contents.push({ role: 'user', parts: [{ text: systemPrompt }] });
    contents.push({ role: 'model', parts: [{ text: 'わかりました。指示に従います。' }] });
  }
  contents.push({ role: 'user', parts: [{ text: prompt }] });

  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ contents }),
    }
  );
  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Gemini API error ${resp.status}: ${err}`);
  }
  const data: any = await resp.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

async function callGeminiWithSearch(apiKey: string, prompt: string): Promise<string> {
  const resp = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        tools: [{ google_search: {} }],
      }),
    }
  );
  if (!resp.ok) {
    const err = await resp.text();
    throw new Error(`Gemini Search API error ${resp.status}: ${err}`);
  }
  const data: any = await resp.json();
  // Collect all text parts from all candidates
  const parts = data.candidates?.[0]?.content?.parts || [];
  return parts.filter((p: any) => p.text).map((p: any) => p.text).join('\n');
}

// --- World keywords for search ---

const WORLD_KEYWORDS: Record<string, string> = {
  medieval: 'ダークファンタジー TRPG シナリオ 地下聖堂 ループ 死に戻り',
  future: 'SF ディストピア TRPG シナリオ 培養槽 記憶消去 クローン',
};

// --- Inspiration collection ---

async function collectInspiration(
  env: Env,
  worldId: string,
  nodeId: string,
  nodeDescription: string,
  conditionKey: string
): Promise<string> {
  // Check cache first
  const cached = await env.DB.prepare(
    `SELECT sources_json FROM inspiration_docs WHERE condition_key = ? LIMIT 1`
  ).bind(conditionKey).first();

  if (cached) {
    return cached.sources_json as string;
  }

  const worldKeywords = WORLD_KEYWORDS[worldId] || WORLD_KEYWORDS.medieval;

  const searchPrompt = `あなたはゲーム「Residue」のリサーチャーです。

【世界設定】
死んでもループする世界。前の周回の痕跡（残痕/Residue）が消し残りとして蓄積される。
キーワード: ${worldKeywords}

【現在の場所】
${nodeDescription || nodeId}

この状況に合うストーリーの元ネタを探してください。
以下のジャンルから幅広く、最低10作品のあらすじをまとめてください：
- TRPGシナリオ（クトゥルフ、ソードワールド等）
- ネット小説（なろう系、カクヨム等のダークファンタジー/SF）
- 古典文学（ダンテ神曲、カフカ、ドストエフスキー等）
- 映画/アニメ（ループもの、ディストピアもの）

各作品について：
1. タイトル
2. あらすじ（3行以内）
3. Residueに活かせる要素

出力形式: JSON配列 [{"title":"...","summary":"...","usable_elements":"..."},...]
JSONのみ出力すること。`;

  try {
    const result = await callGeminiWithSearch(env.GEMINI_API_KEY, searchPrompt);

    // Save to DB
    const docId = 'insp_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
    await env.DB.prepare(
      `INSERT INTO inspiration_docs (doc_id, world_id, node_id, condition_key, sources_json, created_at)
       VALUES (?, ?, ?, ?, ?, datetime('now'))`
    ).bind(docId, worldId, nodeId, conditionKey, result).run();

    return result;
  } catch (e: any) {
    console.error('Inspiration collection failed:', e.message);
    return '[]'; // Non-fatal
  }
}

// --- Few-shot examples ---

const FEW_SHOT_EVENTS = `【お手本1】
テキスト: 「祭壇の蝋燭が、あなたの影だけを映さない。前にここへ来た記憶はないはずなのに、指先が手順を覚えている。」
選択肢:
- 「記憶に従い蝋燭を並べ替える」(curious, sets_flag: altar_rearranged)
- 「影のない自分の手を観察する」(cautious)
- 「蝋燭を全て吹き消す」(bold, damage:10)

【お手本2】
テキスト: 「壁の染みが文字に見える。前回の自分が爪で刻んだ伝言。だが内容は『逃げろ』の一言だけ。」
選択肢:
- 「壁の文字を指でなぞる」(curious, sets_flag: read_wall_message)
- 「伝言に従い引き返す」(cautious, heal:5)
- 「壁を拳で殴り壊す」(defiant, damage:15)`;

// --- Agent prompts ---

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
  inspiration: string;
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

【インスピレーション元ネタ】
${params.inspiration}
↑これらの作品の要素を自由に組み合わせ、Residueの世界観に合う新しいイベントを創作せよ。盗作ではなく変奏。

【周回体験カーブ】
${curveInstruction}

【Residueの核】
死と継承、消し残り、前周回の痕跡、「覚えていないのに体が覚えている」感覚

このノードで起きるイベントのプロットを1段落で書いてください。
何が起き、プレイヤーにどんな選択を迫り、どんな結果になるか。`;
}

function buildWriterPrompt(plot: string): string {
  return `以下のプロットをゲームイベントJSON形式に変換してください。

【プロット】
${plot}

【お手本】
${FEW_SHOT_EVENTS}

【出力形式】必ず以下のJSON形式のみを出力してください。説明文は不要です。
{
  "text_ja": "イベントテキスト（2-3行。短く、鋭く、余韻を残す。体言止めや倒置を活用）",
  "choices": [
    {
      "label": "具体的な行動（『前に進む』禁止。『祭壇の血を舐める』のような具体性）",
      "tags": ["trait_tag"],
      "effect": {"type": "damage", "value": 10},
      "result_text": "結果テキスト（1行、余韻）",
      "sets_flag": null
    }
  ]
}

【制約】
- 選択肢は2-4個。全て異なるプレイスタイルに対応すること
- effectのtypeはdamage/heal/goldのいずれか、valueは5-20
- tagsは以下から選択: merciful, cruel, curious, cautious, bold, reckless, fearless, defiant, obedient, pragmatic, empathetic, thorough, hasty, greedy
- sets_flagはsnake_case、動的に新しいフラグ名を作ってよい（またはnull）
- JSONのみ出力すること`;
}

function buildReviewPrompt(eventJson: string): string {
  return `以下のゲームイベントJSONを品質レビューしてください。

${eventJson}

【評価基準】
1. 雰囲気: ダークファンタジー/ループものの不穏さがあるか（0-1）
2. 選択肢: 具体的で状況に合っているか、「前に進む」的な曖昧さがないか（0-1）
3. 効果値: 5-20範囲内か、選択のリスク/リターンが明確か（0-1）
4. タグ: 選択肢の性格が正しく反映されているか（0-1）
5. 整合性: 世界観に矛盾がないか（0-1）

総合スコア（上記の加重平均）と短いフィードバックをJSON形式で返してください。
0.6未満のイベントは差し戻しになります。

{"quality_score": 0.8, "feedback": "..."}

JSONのみ出力すること。`;
}

// --- Helpers ---

function extractJson(text: string): any {
  try { return JSON.parse(text.trim()); } catch {}
  // Try code block
  const codeBlock = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlock) {
    try { return JSON.parse(codeBlock[1].trim()); } catch {}
  }
  const match = text.match(/\{[\s\S]*\}/);
  if (match) {
    try { return JSON.parse(match[0]); } catch {}
  }
  return null;
}

function generateId(): string {
  return 'ge_' + crypto.randomUUID().replace(/-/g, '').slice(0, 16);
}

// --- Main pipeline ---

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
  retries = 0,
  waitUntil?: (promise: Promise<any>) => void
): Promise<any> {
  const apiKey = env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('GEMINI_API_KEY not configured');
  }

  // Step 0: Use cached inspiration if available, trigger collection in background
  let inspiration = '[]';
  try {
    const cached = await env.DB.prepare(
      `SELECT sources_json FROM inspiration_docs WHERE condition_key = ? LIMIT 1`
    ).bind(params.conditionKey).first();
    if (cached) {
      inspiration = cached.sources_json as string;
    } else {
      // Fire-and-forget: collect inspiration for future requests via waitUntil
      if (waitUntil) {
        waitUntil(
          collectInspiration(
            env, params.worldId, params.nodeId, params.nodeDescription, params.conditionKey
          ).catch(e => console.error('Background inspiration failed:', e.message))
        );
      }
    }
  } catch (e: any) {
    console.error('Inspiration check failed:', e.message);
  }

  // Step 1: Plot
  const plotPrompt = buildPlotPrompt({ ...params, inspiration });
  const plot = await callGemini(apiKey, plotPrompt);

  // Step 2: Writer
  const writerPrompt = buildWriterPrompt(plot);
  const writerOutput = await callGemini(apiKey, writerPrompt);
  const event = extractJson(writerOutput);

  if (!event || !event.text_ja || !event.choices) {
    if (retries < 2) {
      return generateEvent(env, params, retries + 1, waitUntil);
    }
    throw new Error('Failed to generate valid event after retries');
  }

  // Step 3: Review
  const reviewPrompt = buildReviewPrompt(JSON.stringify(event));
  const reviewOutput = await callGemini(apiKey, reviewPrompt);
  const review = extractJson(reviewOutput) || { quality_score: 0.7, feedback: '' };

  if (review.quality_score < 0.6 && retries < 2) {
    return generateEvent(env, params, retries + 1, waitUntil);
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
    'gemini_2.5_flash',
    review.quality_score,
    'active'
  ).run();

  return {
    gen_event_id: genEventId,
    text_ja: event.text_ja,
    choices: event.choices,
    quality_score: review.quality_score,
    generated_by: 'gemini_2.5_flash',
  };
}
