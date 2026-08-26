const ANALYSIS_FOLDER_ID = "1SjxaLhgCa7RmN_czjWluljOKvydsBgnX";
const WARDROBE_FOLDER_ID = "17kl09mmL7DU1JUGDUM2VHie_09HiXQHI";
const PROFILE_FOLDER_ID = "1-mlhprV176uGm7w7WOKRz3Wm0qjI_kFG";

// Used to verify the signed-in Firebase user server-side.
const FIREBASE_PROJECT_ID = "tib-ai-personal-styling";

// ============================================================
// PRODUCT ACCESS MODE
// ============================================================
// Pre-launch/testing mode: ALL authenticated users can use AI features.
// Change to false only when the app is officially launched and Premium
// access should be enforced again.
const PRE_LAUNCH_MODE = true;

// Cheapest/fastest currently supported Claude model, per the product
// decision to keep real AI styling requests low-cost and fast.
const CLAUDE_MODEL = "claude-haiku-4-5-20251001";

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return jsonResponse({
        success: false,
        error: "No request body received."
      });
    }

    const body = JSON.parse(e.postData.contents);

    if (body.action === "delete") {
      return handleDelete(body);
    }

    if (body.action === "aiStyling") {
      return handleAiStyling(body);
    }

    if (body.action === "todayRecommendation") {
      return handleTodayRecommendation(body);
    }

    if (body.action === "virtualTryOn") {
      return handleVirtualTryOn(body);
    }

    const type = body.type || "analysis";

    if (!body.image) {
      return jsonResponse({
        success: false,
        error: "No image data received."
      });
    }

    const folderId = type === "wardrobe"
        ? WARDROBE_FOLDER_ID
        : type === "profile"
        ? PROFILE_FOLDER_ID
        : ANALYSIS_FOLDER_ID;

    const folder = DriveApp.getFolderById(folderId);
    const bytes = Utilities.base64Decode(body.image);
    const fileName = body.fileName || ("image_" + new Date().getTime() + ".jpg");
    const mimeType = body.mimeType || "image/jpeg";

    const blob = Utilities.newBlob(bytes, mimeType, fileName);
    const file = folder.createFile(blob);

    file.setSharing(
      DriveApp.Access.ANYONE_WITH_LINK,
      DriveApp.Permission.VIEW
    );

    const fileId = file.getId();
    const imageUrl = "https://drive.google.com/uc?export=view&id=" + fileId;

    return jsonResponse({
      success: true,
      fileId: fileId,
      imageUrl: imageUrl,
      type: type
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

function handleDelete(body) {
  try {
    const fileId = body.fileId;

    if (!fileId) {
      return jsonResponse({
        success: false,
        error: "No fileId received."
      });
    }

    const file = DriveApp.getFileById(fileId);
    file.setTrashed(true);

    return jsonResponse({
      success: true,
      fileId: fileId,
      deleted: true
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

// =====================================================================
// REAL CLAUDE AI STYLING (All users during pre-launch)
// =====================================================================
// Access model:
//   1. Flutter sends the signed-in user's Firebase ID token and uid.
//   2. Firestore REST verifies that the token really belongs to that uid.
//   3. During PRE_LAUNCH_MODE, every verified signed-in user may use AI.
//   4. When PRE_LAUNCH_MODE is false, only verified Premium users may use AI.
//   5. The Anthropic API key lives only in Script Properties.
// =====================================================================

function handleAiStyling(body) {
  try {
    const uid = body.uid;
    const idToken = body.idToken;

    if (!uid || !idToken) {
      return jsonResponse({
        success: false,
        error: "Missing authentication."
      });
    }

    if (!hasAiAccess(uid, idToken)) {
      return jsonResponse({
        success: false,
        error: "not_premium"
      });
    }

    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");

    if (!apiKey) {
      return jsonResponse({
        success: false,
        error: "AI styling is not configured."
      });
    }

    const wardrobe = Array.isArray(body.wardrobe) ? body.wardrobe : [];

    if (wardrobe.length === 0) {
      return jsonResponse({
        success: false,
        error: "No wardrobe items to style."
      });
    }

    const prompt = buildStylingPrompt(body, wardrobe);

    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method: "post",
      contentType: "application/json",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01"
      },
      payload: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 500,
        messages: [
          { role: "user", content: prompt }
        ]
      }),
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      return jsonResponse({
        success: false,
        error: "AI styling request failed."
      });
    }

    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;

    if (!textBlock) {
      return jsonResponse({
        success: false,
        error: "AI styling returned no content."
      });
    }

    const parsed = parseStylingJson(textBlock);

    if (!parsed) {
      return jsonResponse({
        success: false,
        error: "AI styling response could not be read."
      });
    }

    const validIds = {};
    for (let i = 0; i < wardrobe.length; i++) {
      if (wardrobe[i] && wardrobe[i].id) {
        validIds[wardrobe[i].id] = true;
      }
    }

    const topId = (parsed.topId && validIds[parsed.topId]) ? parsed.topId : null;
    const bottomId = (parsed.bottomId && validIds[parsed.bottomId]) ? parsed.bottomId : null;
    const shoesId = (parsed.shoesId && validIds[parsed.shoesId]) ? parsed.shoesId : null;
    const accessoryId = (parsed.accessoryId && validIds[parsed.accessoryId]) ? parsed.accessoryId : null;
    const explanation = typeof parsed.explanation === "string" ? parsed.explanation.trim() : "";

    if (!explanation && !topId && !bottomId && !shoesId && !accessoryId) {
      return jsonResponse({
        success: false,
        error: "AI styling returned nothing usable."
      });
    }

    return jsonResponse({
      success: true,
      explanation: explanation,
      topId: topId,
      bottomId: bottomId,
      shoesId: shoesId,
      accessoryId: accessoryId
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

// =====================================================================
// TODAY'S RECOMMENDATION (All users during pre-launch)
// =====================================================================

function handleTodayRecommendation(body) {
  try {
    const uid = body.uid;
    const idToken = body.idToken;

    if (!uid || !idToken) {
      return jsonResponse({
        success: false,
        error: "Missing authentication."
      });
    }

    if (!hasAiAccess(uid, idToken)) {
      return jsonResponse({
        success: false,
        error: "not_premium"
      });
    }

    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");

    if (!apiKey) {
      return jsonResponse({
        success: false,
        error: "AI recommendation is not configured."
      });
    }

    const prompt = buildTodayRecommendationPrompt(body);

    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method: "post",
      contentType: "application/json",
      headers: {
        "x-api-key": apiKey,
        "anthropic-version": "2023-06-01"
      },
      payload: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 700,
        messages: [
          { role: "user", content: prompt }
        ]
      }),
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      return jsonResponse({
        success: false,
        error: "AI recommendation request failed."
      });
    }

    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;

    if (!textBlock) {
      return jsonResponse({
        success: false,
        error: "AI recommendation returned no content."
      });
    }

    const parsed = parseStylingJson(textBlock);

    if (!parsed) {
      return jsonResponse({
        success: false,
        error: "AI recommendation response could not be read."
      });
    }

    const result = sanitizeTodayRecommendation(parsed, body);

    if (!result.styleDirection || !result.recommendedColour || !result.outfitFormula || !result.whyItWorks) {
      return jsonResponse({
        success: false,
        error: "AI recommendation returned incomplete content."
      });
    }

    return jsonResponse({
      success: true,
      recommendation: result
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

function buildTodayRecommendationPrompt(body) {
  const profile = body.profile || {};
  const tibModel = body.tibModel || {};
  const wardrobe = Array.isArray(body.wardrobe) ? body.wardrobe : [];
  const styles = Array.isArray(body.styles) ? body.styles : [];
  const preferences = Array.isArray(body.preferences) ? body.preferences : [];
  const occasion = body.occasion || "Everyday";
  const todayColour = body.todayColour || "";
  const date = body.date || "";

  const wardrobeLines = wardrobe.slice(0, 30).map(function(item) {
    return "- " +
      (item.name || "unnamed") +
      " | category: " + (item.category || "unknown") +
      " | colour: " + (item.colour || "unknown") +
      " | style: " + (item.style || "unknown") +
      " | favourite: " + (item.isFavourite ? "yes" : "no");
  }).join("\n");

  return "You are TiB, a warm and practical personal fashion stylist. " +
    "Create ONE useful recommendation for the user's Home Dashboard today. " +
    "Use only the supplied facts. Never invent wardrobe items, measurements, colour-analysis results, or personal facts. " +
    "Do not make medical, body-shaming, or appearance-negative statements. " +
    "Treat body measurements as fit context, not as a reason to judge the user's body.\n\n" +
    "DATE: " + date + "\n" +
    "OCCASION: " + occasion + "\n" +
    "TODAY'S COLOUR: " + (todayColour || "not specified") + "\n\n" +
    "TIB MODEL:\n" +
    "- Face shape: " + (tibModel.faceShape || "unknown") + "\n" +
    "- Body shape: " + (tibModel.bodyShape || "unknown") + "\n" +
    "- Weight: " + (tibModel.weight != null ? tibModel.weight + " kg" : "unknown") + "\n" +
    "- Height: " + (tibModel.height != null ? tibModel.height + " cm" : "unknown") + "\n" +
    "- Bust: " + (tibModel.bust != null ? tibModel.bust + " cm" : "unknown") + "\n" +
    "- Waist: " + (tibModel.waist != null ? tibModel.waist + " cm" : "unknown") + "\n" +
    "- Hips: " + (tibModel.hips != null ? tibModel.hips + " cm" : "unknown") + "\n\n" +
    "COLOUR PROFILE:\n" +
    "- Season: " + (profile.season || "unknown") + "\n" +
    "- Undertone: " + (profile.undertone || "unknown") + "\n" +
    "- Brightness: " + (profile.brightness || "unknown") + "\n" +
    "- Contrast: " + (profile.contrast || "unknown") + "\n" +
    "- Recommended colours: " + ((profile.colours || []).join(", ") || "none") + "\n\n" +
    "STYLE PREFERENCES: " + (styles.concat(preferences).join(", ") || "none") + "\n\n" +
    "WARDROBE:\n" + (wardrobeLines || "No wardrobe items supplied.") + "\n\n" +
    "RECOMMENDATION RULES:\n" +
    "1. Prioritize the user's actual colour profile and today's colour when compatible.\n" +
    "2. Respect the user's body shape as styling context and recommend balanced silhouettes without negative body language.\n" +
    "3. Respect face shape only when it meaningfully affects neckline, earrings, glasses, hair framing, or similar styling details.\n" +
    "4. Prefer real wardrobe items when wardrobe data is supplied. If wardrobe is empty, describe an outfit formula without pretending the user owns specific pieces.\n" +
    "5. Make the recommendation realistic for the occasion.\n" +
    "6. Keep the explanation human, encouraging, specific and concise.\n\n" +
    "Return ONLY valid JSON, with no markdown and no text outside the JSON, exactly in this shape:\n" +
    "{\n" +
    "  \"styleDirection\": \"Short 2-4 word style direction\",\n" +
    "  \"styleTags\": [\"tag1\", \"tag2\", \"tag3\"],\n" +
    "  \"recommendedColour\": \"Colour name\",\n" +
    "  \"outfitFormula\": \"Short outfit formula\",\n" +
    "  \"whyItWorks\": \"1-2 natural sentences\",\n" +
    "  \"stylingTip\": \"One practical styling tip\"\n" +
    "}";
}

function sanitizeTodayRecommendation(parsed, body) {
  function text(value, fallback) {
    return typeof value === "string" ? value.trim() : fallback;
  }

  const tags = Array.isArray(parsed.styleTags)
    ? parsed.styleTags.filter(function(tag) {
        return typeof tag === "string" && tag.trim();
      }).slice(0, 4).map(function(tag) { return tag.trim(); })
    : [];

  const profile = body.profile || {};
  const todayColour = typeof body.todayColour === "string" ? body.todayColour.trim() : "";
  const fallbackColour = todayColour ||
    ((Array.isArray(profile.colours) && profile.colours.length > 0) ? String(profile.colours[0]) : "Your best colour");

  return {
    styleDirection: text(parsed.styleDirection, "Effortless Style"),
    styleTags: tags.length ? tags : ["Personal", "Polished", "Easy"],
    recommendedColour: text(parsed.recommendedColour, fallbackColour),
    outfitFormula: text(parsed.outfitFormula, "Choose a balanced outfit in your recommended colours."),
    whyItWorks: text(parsed.whyItWorks, "This look is designed around your personal styling profile and today's context."),
    stylingTip: text(parsed.stylingTip, "Keep one element simple so the overall look feels effortless.")
  };
}

// Verifies that the Firebase ID token belongs to the supplied uid.
// This does NOT check Premium entitlement.
function isVerifiedUser(uid, idToken) {
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID +
        "/databases/(default)/documents/users/" + encodeURIComponent(uid);

    const response = UrlFetchApp.fetch(url, {
      method: "get",
      headers: {
        "Authorization": "Bearer " + idToken
      },
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      return false;
    }

    return true;
  } catch (error) {
    return false;
  }
}

// Kept for the official-launch phase. Do not remove this helper.
function isVerifiedPremiumUser(uid, idToken) {
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID +
        "/databases/(default)/documents/users/" + encodeURIComponent(uid);

    const response = UrlFetchApp.fetch(url, {
      method: "get",
      headers: {
        "Authorization": "Bearer " + idToken
      },
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      return false;
    }

    const doc = JSON.parse(response.getContentText());
    const fields = doc.fields || {};
    const isPremiumField = fields.isPremium;

    return !!(isPremiumField && isPremiumField.booleanValue === true);
  } catch (error) {
    return false;
  }
}

// Central access switch for AI features.
// true  = every authenticated user can use the feature.
// false = Premium is required.
function hasAiAccess(uid, idToken) {
  if (PRE_LAUNCH_MODE) {
    return isVerifiedUser(uid, idToken);
  }

  return isVerifiedPremiumUser(uid, idToken);
}

function buildStylingPrompt(body, wardrobe) {
  const profile = body.profile || {};
  const styles = Array.isArray(body.styles) ? body.styles : [];
  const preferences = Array.isArray(body.preferences) ? body.preferences : [];
  const occasion = body.occasion || "Everyday";

  const wardrobeLines = wardrobe.map(function (item) {
    return "- id: " + item.id +
        ", name: " + item.name +
        ", category: " + item.category +
        ", colour: " + item.colour +
        ", style: " + item.style +
        ", favourite: " + (item.isFavourite ? "yes" : "no");
  }).join("\n");

  const occasionGuidance = {
    "Everyday": "comfortable, practical and versatile -- easy, casual basics.",
    "Work": "professional, polished and appropriate; prefer more structured, put-together pieces where the wardrobe supports it.",
    "Date": "more polished and coordinated, with personal style emphasis; suggest a real accessory from the wardrobe only if one genuinely lifts the look.",
    "Event": "more elevated, statement styling -- prefer a dressier piece (such as a dress) where the wardrobe supports it, and suggest a real accessory from the wardrobe only if one genuinely fits.",
    "Weekend": "relaxed, casual and comfortable."
  };

  return "You are a personal stylist. Use ONLY the facts given below -- never invent an item, a colour, or a fact that isn't listed here.\n\n" +
      "Colour profile:\n" +
      "- Season: " + (profile.season || "unknown") + "\n" +
      "- Undertone: " + (profile.undertone || "unknown") + "\n" +
      "- Brightness: " + (profile.brightness || "unknown") + "\n" +
      "- Contrast: " + (profile.contrast || "unknown") + "\n" +
      "- Recommended colours: " + ((profile.colours || []).join(", ") || "none") + "\n\n" +
      "Style preferences: " + (styles.concat(preferences).join(", ") || "none") + "\n\n" +
      "Occasion: " + occasion + "\n" +
      "This occasion is a real styling requirement, not just a label -- for " + occasion + " the look should generally be: " +
      (occasionGuidance[occasion] || occasionGuidance["Everyday"]) + "\n\n" +
      "Wardrobe (choose ONLY by id from this exact list):\n" + wardrobeLines + "\n\n" +
      "Pick the single best top/dress, bottom, pair of shoes, and (only if it genuinely helps) one accessory from the wardrobe above, " +
      "for this specific occasion and colour profile " +
      "(use null for any slot with no suitable item -- for example if the best pick is a dress, bottomId may be null, and accessoryId should usually be null unless the occasion and an available item both call for it). " +
      "Then write a short explanation (at most 2 sentences) of why these specific choices suit this specific person for this specific occasion, referencing only the facts above.\n\n" +
      "Respond with ONLY one JSON object and nothing else -- no markdown, no code fences, no text outside the JSON -- in exactly this shape:\n" +
      "{\"explanation\": \"...\", \"topId\": \"...\" or null, \"bottomId\": \"...\" or null, \"shoesId\": \"...\" or null, \"accessoryId\": \"...\" or null}";
}

function parseStylingJson(text) {
  try {
    let cleaned = text.trim();

    if (cleaned.indexOf("```") === 0) {
      cleaned = cleaned.replace(/^```(json)?/i, "").replace(/```$/, "").trim();
    }

    const start = cleaned.indexOf("{");
    const end = cleaned.lastIndexOf("}");

    if (start === -1 || end === -1 || end < start) {
      return null;
    }

    cleaned = cleaned.substring(start, end + 1);
    const parsed = JSON.parse(cleaned);

    if (typeof parsed !== "object" || parsed === null) {
      return null;
    }

    return parsed;
  } catch (error) {
    return null;
  }
}

function doGet() {
  return jsonResponse({
    success: true,
    status: "running",
    service: "TiB AI Personal Styling Drive API"
  });
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}

const GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image";

// ============================================================
// MAIN VIRTUAL TRY-ON HANDLER
// ============================================================

function handleVirtualTryOn(body) {
  try {
    const uid = body.uid;
    const idToken = body.idToken;
    const modelImage = body.modelImage;
    const items = Array.isArray(body.items) ? body.items : [];

    if (
      !uid ||
      !idToken ||
      !modelImage ||
      !modelImage.data ||
      items.length === 0
    ) {
      return jsonResponse({
        success: false,
        error: "Missing model photo or wardrobe items."
      });
    }

    if (items.length > 6) {
      return jsonResponse({
        success: false,
        error: "Choose up to 6 wardrobe pieces."
      });
    }

    // Pre-launch: every authenticated user can use Virtual Try-On.
    // Official launch: hasAiAccess() automatically switches to Premium.
    if (!hasAiAccess(uid, idToken)) {
      return jsonResponse({
        success: false,
        error: "not_premium"
      });
    }

    const apiKey =
      PropertiesService
        .getScriptProperties()
        .getProperty("GEMINI_API_KEY");

    if (!apiKey) {
      return jsonResponse({
        success: false,
        error:
          "Virtual try-on is not configured. Add GEMINI_API_KEY in Script Properties."
      });
    }

    const inputParts = [
      {
        inline_data: {
          mime_type: modelImage.mimeType || "image/jpeg",
          data: modelImage.data
        }
      }
    ];

    const garmentDescriptions = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i] || {};

      if (!item.imageUrl) {
        continue;
      }

      const garment = fetchRemoteImage(item.imageUrl);

      if (!garment) {
        continue;
      }

      inputParts.push({
        inline_data: {
          mime_type: garment.mimeType,
          data: garment.data
        }
      });

      garmentDescriptions.push(
        "Reference garment " +
        (i + 1) +
        ": " +
        (item.category || "item") +
        ", " +
        (item.name || "unnamed") +
        ", colour " +
        (item.colour || "unknown") +
        ", style " +
        (item.style || "unknown")
      );
    }

    if (garmentDescriptions.length === 0) {
      return jsonResponse({
        success: false,
        error:
          "The selected wardrobe images could not be loaded."
      });
    }

    const occasion =
      body.occasion || "Everyday";

    const tibModel = body.tibModel || {};
    const faceShape = tibModel.faceShape || "unknown";
    const bodyShape = tibModel.bodyShape || "unknown";
    const weight = tibModel.weight != null ? tibModel.weight : "unknown";
    const height = tibModel.height != null ? tibModel.height : "unknown";
    const bust = tibModel.bust != null ? tibModel.bust : "unknown";
    const waist = tibModel.waist != null ? tibModel.waist : "unknown";
    const hips = tibModel.hips != null ? tibModel.hips : "unknown";
    const stylingBrief =
      typeof body.stylingBrief === "string"
        ? body.stylingBrief.trim()
        : "";

    const prompt =
      "Create a photorealistic virtual fashion try-on using the provided reference images. " +
      "The FIRST image is the user's own TiB Model reference and is the identity source. " +
      "The following images are the user's actual wardrobe garments and must be treated as exact clothing references. " +
      "Dress the same person in the first image using only the selected wardrobe garments. " +
      "PRESERVE IDENTITY: keep the same face, facial features, skin tone, hair, age appearance and recognizable identity. " +
      "PRESERVE BODY: keep the person's natural body proportions and do not make the person thinner, taller, shorter, or otherwise reshape the body. " +
      "The supplied body measurements are fit and styling context, not permission to change the person's body. " +
      "\n\nTIB MODEL PERSONAL FIT CONTEXT:\n" +
      "Face shape: " + faceShape + "\n" +
      "Body shape: " + bodyShape + "\n" +
      "Height: " + height + " cm\n" +
      "Weight: " + weight + " kg\n" +
      "Bust: " + bust + " cm\n" +
      "Waist: " + waist + " cm\n" +
      "Hips: " + hips + " cm\n" +
      "\n\nOCCASION:\n" +
      occasion +
      (stylingBrief
        ? "\n\nSTYLING BRIEF:\n" + stylingBrief + "\n"
        : "") +
      "\n\nWARDROBE REFERENCE RULES:\n" +
      "Use the exact garments shown in the wardrobe reference images, including their real colours, patterns, materials, textures and silhouettes. " +
      "Do not replace them with visually similar garments. " +
      "Do not invent new clothing, shoes, bags, jewellery or accessories that are not present in the references. " +
      "If a selected piece cannot be realistically used, preserve the other selected pieces rather than inventing a replacement. " +
      "\n\nFIT AND COMPOSITION:\n" +
      "Combine the selected garments into one coherent outfit appropriate for the occasion. " +
      "Make the garments fit naturally according to the person's real body proportions and supplied measurements. " +
      "Preserve realistic garment folds, fabric behaviour, seams, shadows and lighting. " +
      "Keep the full outfit visible from head to toe whenever possible. " +
      "Use a natural standing fashion pose and a clean realistic background. " +
      "\n\nFINAL RESTRICTIONS:\n" +
      "Do not change the person's identity. " +
      "Do not invent a different person. " +
      "Do not alter the person's face to match a model. " +
      "Do not reshape the body into an idealized fashion body. " +
      "Do not add logos or text. " +
      "Do not remove important garment details. " +
      "Keep the result tasteful and suitable for a personal styling application. " +
      "\n\nREFERENCE GARMENTS:\n" +
      garmentDescriptions.join("\n");

    inputParts.push({
      text: prompt
    });

    const endpoint =
      "https://generativelanguage.googleapis.com/v1/models/" +
      GEMINI_IMAGE_MODEL +
      ":generateContent";

    const payload = {
      contents: [
        {
          parts: inputParts
        }
      ],
      generationConfig: {
        responseModalities: ["IMAGE"]
      }
    };

    const response = UrlFetchApp.fetch(
      endpoint,
      {
        method: "post",
        contentType: "application/json",
        headers: {
          "x-goog-api-key": apiKey
        },
        payload: JSON.stringify(payload),
        muteHttpExceptions: true
      }
    );

    if (response.getResponseCode() !== 200) {
      let providerMessage = "";

      try {
        const errorData = JSON.parse(response.getContentText());
        providerMessage =
          errorData.error && errorData.error.message
            ? errorData.error.message
            : "";
      } catch (_) {
        providerMessage = "";
      }

      return jsonResponse({
        success: false,
        error:
          providerMessage ||
          "Virtual try-on generation failed.",
        providerStatus:
          response.getResponseCode()
      });
    }

    const data = JSON.parse(response.getContentText());
    const imagePart = extractGeneratedImagePart(data);

    if (!imagePart || !imagePart.data) {
      return jsonResponse({
        success: false,
        error:
          "Virtual try-on returned no image."
      });
    }

    const folder = getVirtualTryOnFolder();
    const bytes = Utilities.base64Decode(imagePart.data);

    const blob = Utilities.newBlob(
      bytes,
      imagePart.mimeType || "image/png",
      "try_on_" +
        new Date().getTime() +
        ".png"
    );

    const file = folder.createFile(blob);

    file.setSharing(
      DriveApp.Access.ANYONE_WITH_LINK,
      DriveApp.Permission.VIEW
    );

    return jsonResponse({
      success: true,
      imageUrl:
        "https://drive.google.com/uc?export=view&id=" +
        file.getId(),
      fileId:
        file.getId(),
      provider:
        GEMINI_IMAGE_MODEL,
      occasion: occasion,
      selectedItemCount: items.length,
      tibModel: {
        faceShape: faceShape,
        bodyShape: bodyShape
      }
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error:
        error && error.toString
          ? error.toString()
          : "Unknown virtual try-on error."
    });
  }
}

function fetchRemoteImage(url) {
  try {
    if (
      typeof url !== "string" ||
      !/^https:\/\//i.test(url)
    ) {
      return null;
    }

    const response =
      UrlFetchApp.fetch(
        url,
        {
          method: "get",
          muteHttpExceptions: true
        }
      );

    if (
      response.getResponseCode() !== 200
    ) {
      return null;
    }

    const blob =
      response.getBlob();

    const mimeType =
      blob.getContentType() ||
      "image/jpeg";

    if (
      mimeType.indexOf("image/") !== 0
    ) {
      return null;
    }

    return {
      mimeType: mimeType,
      data:
        Utilities.base64Encode(
          blob.getBytes()
        )
    };
  } catch (_) {
    return null;
  }
}

function extractGeneratedImagePart(data) {
  try {
    const candidates =
      data.candidates || [];

    for (
      let i = 0;
      i < candidates.length;
      i++
    ) {
      const parts =
        candidates[i].content &&
        candidates[i].content.parts;

      if (!Array.isArray(parts)) {
        continue;
      }

      for (
        let j = 0;
        j < parts.length;
        j++
      ) {
        const inlineData =
          parts[j].inlineData ||
          parts[j].inline_data;

        if (
          inlineData &&
          inlineData.data
        ) {
          return {
            data:
              inlineData.data,
            mimeType:
              inlineData.mimeType ||
              inlineData.mime_type ||
              "image/png"
          };
        }
      }
    }
  } catch (_) {}

  return null;
}

function getVirtualTryOnFolder() {
  const parent =
    DriveApp.getFolderById(
      PROFILE_FOLDER_ID
    );

  const folders =
    parent.getFoldersByName(
      "virtual_try_on"
    );

  if (folders.hasNext()) {
    return folders.next();
  }

  return parent.createFolder(
    "virtual_try_on"
  );
}
