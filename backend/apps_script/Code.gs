const ANALYSIS_FOLDER_ID = "1SjxaLhgCa7RmN_czjWluljOKvydsBgnX";
const WARDROBE_FOLDER_ID = "17kl09mmL7DU1JUGDUM2VHie_09HiXQHI";
const PROFILE_FOLDER_ID = "1-mlhprV176uGm7w7WOKRz3Wm0qjI_kFG";
const FIREBASE_PROJECT_ID = "tib-ai-personal-styling";
const PRE_LAUNCH_MODE = true;
const CLAUDE_MODEL = "claude-haiku-4-5-20251001";
const GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image";
const CODE_VERSION = "VTO_PERSONAL_MODEL_2026_08_27";

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) return jsonResponse({success:false,errorCode:"missing_input",error:"No request body received."});
    const body = JSON.parse(e.postData.contents);
    if (body.action === "delete") return handleDelete(body);
    if (body.action === "aiStyling") return handleAiStyling(body);
    if (body.action === "todayRecommendation") return handleTodayRecommendation(body);
    if (body.action === "virtualTryOn") return handleVirtualTryOn(body);

    const type = body.type || "analysis";
    if (!body.image) return jsonResponse({success:false,errorCode:"missing_input",error:"No image data received."});
    const folderId = type === "wardrobe" ? WARDROBE_FOLDER_ID : type === "profile" ? PROFILE_FOLDER_ID : ANALYSIS_FOLDER_ID;
    const folder = DriveApp.getFolderById(folderId);
    const bytes = Utilities.base64Decode(body.image);
    const file = folder.createFile(Utilities.newBlob(bytes, body.mimeType || "image/jpeg", body.fileName || ("image_" + new Date().getTime() + ".jpg")));
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    const fileId = file.getId();
    return jsonResponse({success:true,fileId:fileId,imageUrl:"https://drive.google.com/uc?export=view&id=" + fileId,type:type});
  } catch (error) {
    return jsonResponse({success:false,errorCode:"unhandled_exception",error:error.toString()});
  }
}

function handleDelete(body) {
  try {
    if (!body.fileId) return jsonResponse({success:false,errorCode:"missing_input",error:"No fileId received."});
    DriveApp.getFileById(body.fileId).setTrashed(true);
    return jsonResponse({success:true,fileId:body.fileId,deleted:true});
  } catch (error) {
    return jsonResponse({success:false,errorCode:"delete_failed",error:error.toString()});
  }
}

function handleAiStyling(body) {
  try {
    if (!body.uid || !body.idToken) return jsonResponse({success:false,errorCode:"missing_auth",error:"Missing authentication."});
    // Talk to TiB is a free feature. Verify that the account is authenticated,
    // but deliberately do not check the Premium entitlement here.
    const access = verifyFirebaseUser(body.uid, body.idToken);
    if (!access.ok) return jsonResponse(access);
    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");
    if (!apiKey) return jsonResponse({success:false,errorCode:"missing_api_key",error:"AI styling is not configured."});
    const wardrobe = Array.isArray(body.wardrobe) ? body.wardrobe : [];
    if (wardrobe.length === 0) return jsonResponse({success:false,errorCode:"missing_wardrobe",error:"No wardrobe items to style."});
    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method:"post", contentType:"application/json",
      headers:{"x-api-key":apiKey,"anthropic-version":"2023-06-01"},
      payload:JSON.stringify({model:CLAUDE_MODEL,max_tokens:500,messages:[{role:"user",content:buildStylingPrompt(body,wardrobe)}]}),
      muteHttpExceptions:true
    });
    if (response.getResponseCode() !== 200) return jsonResponse({success:false,errorCode:"ai_provider_error",error:"AI styling request failed.",providerStatus:response.getResponseCode()});
    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;
    if (!textBlock) return jsonResponse({success:false,errorCode:"ai_empty_response",error:"AI styling returned no content."});
    const parsed = parseStylingJson(textBlock);
    if (!parsed) return jsonResponse({success:false,errorCode:"ai_parse_error",error:"AI styling response could not be read."});
    const validIds = {};
    wardrobe.forEach(function(item){ if(item && item.id) validIds[item.id] = true; });
    return jsonResponse({success:true,explanation:typeof parsed.explanation === "string" ? parsed.explanation.trim() : "",topId:parsed.topId && validIds[parsed.topId] ? parsed.topId : null,bottomId:parsed.bottomId && validIds[parsed.bottomId] ? parsed.bottomId : null,shoesId:parsed.shoesId && validIds[parsed.shoesId] ? parsed.shoesId : null,accessoryId:parsed.accessoryId && validIds[parsed.accessoryId] ? parsed.accessoryId : null});
  } catch (error) {
    return jsonResponse({success:false,errorCode:"unhandled_exception",error:error.toString()});
  }
}

function handleTodayRecommendation(body) {
  try {
    if (!body.uid || !body.idToken) return jsonResponse({success:false,errorCode:"missing_auth",error:"Missing authentication."});
    const access = checkAiAccess(body.uid, body.idToken);
    if (!access.ok) return jsonResponse(access);
    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");
    if (!apiKey) return jsonResponse({success:false,errorCode:"missing_api_key",error:"AI recommendation is not configured."});
    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method:"post", contentType:"application/json",
      headers:{"x-api-key":apiKey,"anthropic-version":"2023-06-01"},
      payload:JSON.stringify({model:CLAUDE_MODEL,max_tokens:700,messages:[{role:"user",content:buildTodayRecommendationPrompt(body)}]}),
      muteHttpExceptions:true
    });
    if (response.getResponseCode() !== 200) return jsonResponse({success:false,errorCode:"ai_provider_error",error:"AI recommendation request failed.",providerStatus:response.getResponseCode()});
    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;
    if (!textBlock) return jsonResponse({success:false,errorCode:"ai_empty_response",error:"AI recommendation returned no content."});
    const parsed = parseStylingJson(textBlock);
    if (!parsed) return jsonResponse({success:false,errorCode:"ai_parse_error",error:"AI recommendation response could not be read."});
    const result = sanitizeTodayRecommendation(parsed,body);
    if (!result.styleDirection || !result.recommendedColour || !result.outfitFormula || !result.whyItWorks) return jsonResponse({success:false,errorCode:"ai_incomplete_response",error:"AI recommendation returned incomplete content."});
    return jsonResponse({success:true,recommendation:result});
  } catch (error) {
    return jsonResponse({success:false,errorCode:"unhandled_exception",error:error.toString()});
  }
}

function verifyFirebaseUser(uid,idToken) {
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/users/" + encodeURIComponent(uid);
    const response = UrlFetchApp.fetch(url,{method:"get",headers:{"Authorization":"Bearer " + idToken},muteHttpExceptions:true});
    const status = response.getResponseCode();
    if (status === 200) return {ok:true,errorCode:""};
    if (status === 401) return {ok:false,errorCode:"auth_invalid",error:"Your sign-in token is invalid or expired. Please sign in again."};
    if (status === 404) return {ok:false,errorCode:"user_not_found",error:"Your TiB user profile could not be found."};
    return {ok:false,errorCode:"firestore_error",error:"TiB could not verify your account right now.",providerStatus:status};
  } catch (error) {
    return {ok:false,errorCode:"network_error",error:error.toString()};
  }
}

function isVerifiedPremiumUser(uid,idToken) {
  const verification = verifyFirebaseUser(uid,idToken);
  if (!verification.ok) return verification;
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/users/" + encodeURIComponent(uid);
    const response = UrlFetchApp.fetch(url,{method:"get",headers:{"Authorization":"Bearer " + idToken},muteHttpExceptions:true});
    if (response.getResponseCode() !== 200) return {ok:false,errorCode:"firestore_error",error:"TiB could not verify Premium access.",providerStatus:response.getResponseCode()};
    const doc = JSON.parse(response.getContentText());
    const fields = doc.fields || {};
    if (fields.isPremium && fields.isPremium.booleanValue === true) return {ok:true,errorCode:""};
    return {ok:false,errorCode:"not_premium",error:"Virtual Try-On requires the Premium plan."};
  } catch (error) {
    return {ok:false,errorCode:"firestore_error",error:error.toString()};
  }
}

function checkAiAccess(uid,idToken) {
  if (!uid || !idToken) return {ok:false,errorCode:"missing_auth",error:"Missing authentication."};
  // Pre-launch: every authenticated app account can use AI.
  // Production: restore the Premium entitlement check.
  if (PRE_LAUNCH_MODE) return verifyFirebaseUser(uid,idToken);
  return isVerifiedPremiumUser(uid,idToken);
}

function buildStylingPrompt(body,wardrobe) {
  const profile = body.profile || {};
  const styles = Array.isArray(body.styles) ? body.styles : [];
  const preferences = Array.isArray(body.preferences) ? body.preferences : [];
  const occasion = body.occasion || "Everyday";
  const wardrobeLines = wardrobe.map(function(item){return "- id: " + item.id + ", name: " + item.name + ", category: " + item.category + ", colour: " + item.colour + ", style: " + item.style + ", favourite: " + (item.isFavourite ? "yes" : "no");}).join("\n");
  return "You are a personal stylist. Use ONLY the facts given below -- never invent an item, a colour, or a fact that isn't listed here.\n\nColour profile:\n- Season: " + (profile.season || "unknown") + "\n- Undertone: " + (profile.undertone || "unknown") + "\n- Brightness: " + (profile.brightness || "unknown") + "\n- Contrast: " + (profile.contrast || "unknown") + "\n- Recommended colours: " + ((profile.colours || []).join(", ") || "none") + "\n\nStyle preferences: " + (styles.concat(preferences).join(", ") || "none") + "\n\nOccasion: " + occasion + "\n\nWardrobe:\n" + wardrobeLines + "\n\nPick the best top/dress, bottom, shoes, and optional accessory. Use null for unsuitable slots. Return ONLY JSON: {\"explanation\":\"...\",\"topId\":\"...\",\"bottomId\":\"...\",\"shoesId\":\"...\",\"accessoryId\":\"...\"}";
}

function buildTodayRecommendationPrompt(body) {
  const profile = body.profile || {};
  const tib = body.tibModel || {};
  const wardrobe = Array.isArray(body.wardrobe) ? body.wardrobe : [];
  const occasion = body.occasion || "Everyday";
  const colour = body.todayColour || "not specified";
  const lines = wardrobe.slice(0,30).map(function(item){return "- " + (item.name || "unnamed") + " | category: " + (item.category || "unknown") + " | colour: " + (item.colour || "unknown") + " | style: " + (item.style || "unknown");}).join("\n");
  return "You are TiB, a warm and practical personal fashion stylist. Create ONE useful recommendation. Use only supplied facts. Occasion: " + occasion + "\nToday's colour: " + colour + "\nBody shape: " + (tib.bodyShape || "unknown") + "\nFace shape: " + (tib.faceShape || "unknown") + "\nSeason: " + (profile.season || "unknown") + "\nRecommended colours: " + ((profile.colours || []).join(", ") || "none") + "\nWardrobe:\n" + (lines || "No wardrobe items supplied.") + "\nReturn ONLY JSON with styleDirection,styleTags,recommendedColour,outfitFormula,whyItWorks,stylingTip.";
}

function sanitizeTodayRecommendation(parsed,body) {
  function text(value,fallback){return typeof value === "string" ? value.trim() : fallback;}
  const tags = Array.isArray(parsed.styleTags) ? parsed.styleTags.filter(function(tag){return typeof tag === "string" && tag.trim();}).slice(0,4).map(function(tag){return tag.trim();}) : [];
  const profile = body.profile || {};
  const todayColour = typeof body.todayColour === "string" ? body.todayColour.trim() : "";
  const fallbackColour = todayColour || ((Array.isArray(profile.colours) && profile.colours.length > 0) ? String(profile.colours[0]) : "Your best colour");
  return {styleDirection:text(parsed.styleDirection,"Effortless Style"),styleTags:tags.length ? tags : ["Personal","Polished","Easy"],recommendedColour:text(parsed.recommendedColour,fallbackColour),outfitFormula:text(parsed.outfitFormula,"Choose a balanced outfit in your recommended colours."),whyItWorks:text(parsed.whyItWorks,"This look is designed around your personal styling profile and today's context."),stylingTip:text(parsed.stylingTip,"Keep one element simple so the overall look feels effortless.")};
}

function parseStylingJson(text) {
  try {
    var cleaned = String(text).trim();
    if (cleaned.indexOf("```") === 0) cleaned = cleaned.replace(/^```(json)?/i,"").replace(/```$/i,"").trim();
    var start = cleaned.indexOf("{");
    var end = cleaned.lastIndexOf("}");
    if (start === -1 || end < start) return null;
    var parsed = JSON.parse(cleaned.substring(start,end+1));
    return parsed && typeof parsed === "object" ? parsed : null;
  } catch (error) { return null; }
}

function handleVirtualTryOn(body) {
  const requestId = Utilities.getUuid();
  try {
    const uid = body.uid;
    const idToken = body.idToken;
    const faceReference = body.modelImage;
    const bodyReference = body.bodyImage;
    const personalModel = body.personalModel || {};
    const virtualYou = body.personalVirtualYou || {};
    const items = Array.isArray(body.items) ? body.items : [];
    if (!uid || !idToken || !faceReference || !faceReference.data || items.length === 0) return jsonResponse({success:false,errorCode:"missing_input",error:"Missing model photo or wardrobe items.",requestId:requestId});
    if (items.length > 6) return jsonResponse({success:false,errorCode:"too_many_items",error:"Choose up to 6 wardrobe pieces.",requestId:requestId});
    const access = checkAiAccess(uid,idToken);
    if (!access.ok) return jsonResponse(Object.assign({},access,{requestId:requestId}));
    const apiKey = PropertiesService.getScriptProperties().getProperty("GEMINI_API_KEY");
    if (!apiKey) return jsonResponse({success:false,errorCode:"missing_api_key",error:"Virtual try-on is not configured. Add GEMINI_API_KEY in Script Properties.",requestId:requestId});

    const inputParts = [];
    let hasBodyReference = false;
    if (bodyReference && bodyReference.data) {
      inputParts.push({inline_data:{mime_type:bodyReference.mimeType || "image/jpeg",data:bodyReference.data}});
      hasBodyReference = true;
    }
    inputParts.push({inline_data:{mime_type:faceReference.mimeType || "image/jpeg",data:faceReference.data}});

    const garmentDescriptions = [];
    const garmentErrors = [];
    for (let i=0;i<items.length;i++) {
      const item = items[i] || {};
      if (!item.imageUrl) {
        garmentErrors.push("item " + (i + 1) + ": missing imageUrl");
        continue;
      }
      const garment = fetchRemoteImage(item.imageUrl);
      if (!garment) {
        garmentErrors.push("item " + (i + 1) + ": image could not be read");
        continue;
      }
      inputParts.push({inline_data:{mime_type:garment.mimeType,data:garment.data}});
      garmentDescriptions.push("Reference garment " + (garmentDescriptions.length + 1) + ": category=" + (item.category || "item") + ", name=" + (item.name || "unnamed") + ", colour=" + (item.colour || "unknown") + ", style=" + (item.style || "unknown"));
    }
    if (garmentDescriptions.length === 0) return jsonResponse({success:false,errorCode:"wardrobe_image_load_failed",error:"The selected wardrobe images could not be loaded.",details:garmentErrors.join("; "),requestId:requestId});

    const tib = body.tibModel || {};
    const occasion = body.occasion || "Everyday";
    const brief = typeof body.stylingBrief === "string" ? body.stylingBrief.trim() : "";
    const proportions = tib.proportionRatios || (virtualYou.body && virtualYou.body.proportions) || personalModel.proportionRatios || {};
    const prompt = "Create a photorealistic PERSONAL VIRTUAL YOU fashion try-on for TiB. " +
      "This is a real user and the output is NOT a generic fashion model. " +
      "REFERENCE A is the user's own full-body photograph and is the PRIMARY silhouette, body-size and proportion anchor. " +
      "REFERENCE B is the user's own face photograph and is the PRIMARY facial identity anchor. " +
      "The remaining image references are the user's actual selected wardrobe pieces. " +
      "IDENTITY LOCK: preserve the same recognizable person, facial structure, eyes, nose, lips, skin tone, hair and natural appearance. " +
      "BODY LOCK: preserve the exact natural silhouette visible in the full-body reference, including shoulder width, torso length, waist placement, hip width, leg length and overall scale. Do not slim, enlarge, lengthen, shorten, reshape or idealize the body. " +
      "MEASUREMENT LOCK: use the supplied height, weight, bust, waist and hip measurements as hard fit context; they are not decorative metadata. " +
      "Do not substitute a fashion-model body even if the clothing normally looks better on one. " +
      "GARMENT LOCK: dress the person ONLY in the selected wardrobe references. Preserve each garment's real colour, print, texture, fabric, cut, seams, neckline, sleeves, hem and construction. Do not invent replacement garments, shoes, bags or accessories. " +
      "Occasion: " + occasion + ". " +
      "Personal TiB body shape: " + (tib.bodyShape || personalModel.bodyShape || "unknown") + ", face shape: " + (tib.faceShape || personalModel.faceShape || "unknown") + ". " +
      "Height: " + (tib.heightCm != null ? tib.heightCm : personalModel.heightCm != null ? personalModel.heightCm : "unknown") + " cm. " +
      "Weight: " + (tib.weightKg != null ? tib.weightKg : personalModel.weightKg != null ? personalModel.weightKg : "unknown") + " kg. " +
      "Bust: " + (tib.bustCm != null ? tib.bustCm : personalModel.bustCm != null ? personalModel.bustCm : "unknown") + " cm. " +
      "Waist: " + (tib.waistCm != null ? tib.waistCm : personalModel.waistCm != null ? personalModel.waistCm : "unknown") + " cm. " +
      "Hips: " + (tib.hipsCm != null ? tib.hipsCm : personalModel.hipsCm != null ? personalModel.hipsCm : "unknown") + " cm. " +
      "Proportion ratios: waist/bust=" + (proportions.waistToBust || "unknown") + ", waist/hips=" + (proportions.waistToHips || "unknown") + ", hips/bust=" + (proportions.hipsToBust || "unknown") + ". " +
      (brief ? "Additional styling brief: " + brief + ". " : "") +
      "COMPOSITION: generate ONE complete head-to-toe fashion image whenever possible. Keep the full body visible from head through feet, use a natural standing pose, realistic garment fit, natural folds, believable shadows and lighting, and a clean editorial background. " +
      "The final image should look like a real photograph of THIS user wearing the user's own selected clothes. Do not output a mannequin, illustration, beauty-model replacement or generic avatar. " +
      "REFERENCE GARMENTS:\n" + garmentDescriptions.join("\n");

    inputParts.push({text:prompt});
    const endpoint = "https://generativelanguage.googleapis.com/v1/models/" + GEMINI_IMAGE_MODEL + ":generateContent";
    const response = UrlFetchApp.fetch(endpoint,{method:"post",contentType:"application/json",headers:{"x-goog-api-key":apiKey},payload:JSON.stringify({contents:[{parts:inputParts}],generationConfig:{responseModalities:["IMAGE"]}}),muteHttpExceptions:true});
    if (response.getResponseCode() !== 200) {
      let providerMessage = "";
      try { const errorData = JSON.parse(response.getContentText()); providerMessage = errorData.error && errorData.error.message ? errorData.error.message : ""; } catch (error) {}
      return jsonResponse({success:false,errorCode:"ai_provider_error",error:providerMessage || "Virtual try-on generation failed.",providerStatus:response.getResponseCode(),requestId:requestId});
    }
    const data = JSON.parse(response.getContentText());
    const imagePart = extractGeneratedImagePart(data);
    if (!imagePart || !imagePart.data) return jsonResponse({success:false,errorCode:"ai_empty_response",error:"Virtual try-on returned no image.",requestId:requestId});

    const folder = getVirtualTryOnFolder();
    const blob = Utilities.newBlob(Utilities.base64Decode(imagePart.data),imagePart.mimeType || "image/png","try_on_" + new Date().getTime() + ".png");
    const file = folder.createFile(blob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK,DriveApp.Permission.VIEW);
    return jsonResponse({success:true,requestId:requestId,imageUrl:"https://drive.google.com/uc?export=view&id=" + file.getId(),fileId:file.getId(),provider:GEMINI_IMAGE_MODEL,occasion:occasion,selectedItemCount:items.length,usedBodyReference:hasBodyReference,modelType:"personal_tib_model",identityMode:"real_user",codeVersion:CODE_VERSION,tibModel:{faceShape:tib.faceShape || personalModel.faceShape || "unknown",bodyShape:tib.bodyShape || personalModel.bodyShape || "unknown",heightCm:tib.heightCm || personalModel.heightCm || null,weightKg:tib.weightKg || personalModel.weightKg || null,bustCm:tib.bustCm || personalModel.bustCm || null,waistCm:tib.waistCm || personalModel.waistCm || null,hipsCm:tib.hipsCm || personalModel.hipsCm || null}});
  } catch (error) {
    return jsonResponse({success:false,errorCode:"unhandled_exception",error:error && error.toString ? error.toString() : "Unknown virtual try-on error.",requestId:requestId});
  }
}

function extractDriveFileId(url) {
  if (typeof url !== "string") return null;
  const value = url.trim();
  if (!value) return null;
  let match = value.match(/drive\.google\.com\/file\/d\/([a-zA-Z0-9_-]+)/i);
  if (match) return match[1];
  match = value.match(/[?&](?:id|fileId)=([a-zA-Z0-9_-]+)/i);
  if (match) return match[1];
  match = value.match(/drive\.usercontent\.google\.com\/download\?id=([a-zA-Z0-9_-]+)/i);
  if (match) return match[1];
  return null;
}

function imageBlobToData(blob) {
  if (!blob) return null;
  const mimeType = blob.getContentType() || "image/jpeg";
  if (mimeType.toLowerCase().indexOf("image/") !== 0) return null;
  const bytes = blob.getBytes();
  if (!bytes || bytes.length === 0) return null;
  return {mimeType:mimeType,data:Utilities.base64Encode(bytes)};
}

function fetchRemoteImage(url) {
  try {
    if (typeof url !== "string" || !/^https:\/\//i.test(url)) return null;
    const driveFileId = extractDriveFileId(url);
    if (driveFileId) {
      try {
        const file = DriveApp.getFileById(driveFileId);
        const direct = imageBlobToData(file.getBlob());
        if (direct) return direct;
      } catch (driveError) {}
    }
    const response = UrlFetchApp.fetch(url,{method:"get",followRedirects:true,muteHttpExceptions:true,headers:{"User-Agent":"Mozilla/5.0 TiB-AI-Personal-Styling"}});
    const status = response.getResponseCode();
    if (status < 200 || status >= 300) return null;
    return imageBlobToData(response.getBlob());
  } catch (error) { return null; }
}

function extractGeneratedImagePart(data) {
  try {
    const candidates = data.candidates || [];
    for (let i=0;i<candidates.length;i++) {
      const parts = candidates[i].content && candidates[i].content.parts;
      if (!Array.isArray(parts)) continue;
      for (let j=0;j<parts.length;j++) {
        const inlineData = parts[j].inlineData || parts[j].inline_data;
        if (inlineData && inlineData.data) return {data:inlineData.data,mimeType:inlineData.mimeType || inlineData.mime_type || "image/png"};
      }
    }
  } catch (error) {}
  return null;
}

function getVirtualTryOnFolder() {
  const parent = DriveApp.getFolderById(PROFILE_FOLDER_ID);
  const folders = parent.getFoldersByName("virtual_try_on");
  return folders.hasNext() ? folders.next() : parent.createFolder("virtual_try_on");
}

function jsonResponse(data) {
  if (!data || typeof data !== "object") data = {success:false,errorCode:"invalid_response",error:"Invalid backend response."};
  if (!data.codeVersion) data.codeVersion = CODE_VERSION;
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}