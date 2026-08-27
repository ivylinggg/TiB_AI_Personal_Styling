const ANALYSIS_FOLDER_ID = "1SjxaLhgCa7RmN_czjWluljOKvydsBgnX";
const WARDROBE_FOLDER_ID = "17kl09mmL7DU1JUGDUM2VHie_09HiXQHI";
const PROFILE_FOLDER_ID = "1-mlhprV176uGm7w7WOKRz3Wm0qjI_kFG";
const FIREBASE_PROJECT_ID = "tib-ai-personal-styling";
const PRE_LAUNCH_MODE = true;
const CLAUDE_MODEL = "claude-haiku-4-5-20251001";
const GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image";

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) return jsonResponse({success:false,error:"No request body received."});
    const body = JSON.parse(e.postData.contents);
    if (body.action === "delete") return handleDelete(body);
    if (body.action === "aiStyling") return handleAiStyling(body);
    if (body.action === "todayRecommendation") return handleTodayRecommendation(body);
    if (body.action === "virtualTryOn") return handleVirtualTryOn(body);

    const type = body.type || "analysis";
    if (!body.image) return jsonResponse({success:false,error:"No image data received."});
    const folderId = type === "wardrobe" ? WARDROBE_FOLDER_ID : type === "profile" ? PROFILE_FOLDER_ID : ANALYSIS_FOLDER_ID;
    const folder = DriveApp.getFolderById(folderId);
    const bytes = Utilities.base64Decode(body.image);
    const file = folder.createFile(Utilities.newBlob(bytes, body.mimeType || "image/jpeg", body.fileName || ("image_" + new Date().getTime() + ".jpg")));
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
    const fileId = file.getId();
    return jsonResponse({success:true,fileId:fileId,imageUrl:"https://drive.google.com/uc?export=view&id=" + fileId,type:type});
  } catch (error) {
    return jsonResponse({success:false,error:error.toString()});
  }
}

function handleDelete(body) {
  try {
    if (!body.fileId) return jsonResponse({success:false,error:"No fileId received."});
    DriveApp.getFileById(body.fileId).setTrashed(true);
    return jsonResponse({success:true,fileId:body.fileId,deleted:true});
  } catch (error) {
    return jsonResponse({success:false,error:error.toString()});
  }
}

function handleAiStyling(body) {
  try {
    if (!body.uid || !body.idToken) return jsonResponse({success:false,error:"Missing authentication."});
    if (!hasAiAccess(body.uid, body.idToken)) return jsonResponse({success:false,error:"not_premium"});
    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");
    if (!apiKey) return jsonResponse({success:false,error:"AI styling is not configured."});
    const wardrobe = Array.isArray(body.wardrobe) ? body.wardrobe : [];
    if (wardrobe.length === 0) return jsonResponse({success:false,error:"No wardrobe items to style."});
    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method:"post", contentType:"application/json",
      headers:{"x-api-key":apiKey,"anthropic-version":"2023-06-01"},
      payload:JSON.stringify({model:CLAUDE_MODEL,max_tokens:500,messages:[{role:"user",content:buildStylingPrompt(body,wardrobe)}]}),
      muteHttpExceptions:true
    });
    if (response.getResponseCode() !== 200) return jsonResponse({success:false,error:"AI styling request failed."});
    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;
    if (!textBlock) return jsonResponse({success:false,error:"AI styling returned no content."});
    const parsed = parseStylingJson(textBlock);
    if (!parsed) return jsonResponse({success:false,error:"AI styling response could not be read."});
    const validIds = {};
    wardrobe.forEach(function(item){ if(item && item.id) validIds[item.id] = true; });
    return jsonResponse({success:true,explanation:typeof parsed.explanation === "string" ? parsed.explanation.trim() : "",topId:parsed.topId && validIds[parsed.topId] ? parsed.topId : null,bottomId:parsed.bottomId && validIds[parsed.bottomId] ? parsed.bottomId : null,shoesId:parsed.shoesId && validIds[parsed.shoesId] ? parsed.shoesId : null,accessoryId:parsed.accessoryId && validIds[parsed.accessoryId] ? parsed.accessoryId : null});
  } catch (error) {
    return jsonResponse({success:false,error:error.toString()});
  }
}

function handleTodayRecommendation(body) {
  try {
    if (!body.uid || !body.idToken) return jsonResponse({success:false,error:"Missing authentication."});
    if (!hasAiAccess(body.uid, body.idToken)) return jsonResponse({success:false,error:"not_premium"});
    const apiKey = PropertiesService.getScriptProperties().getProperty("ANTHROPIC_API_KEY");
    if (!apiKey) return jsonResponse({success:false,error:"AI recommendation is not configured."});
    const response = UrlFetchApp.fetch("https://api.anthropic.com/v1/messages", {
      method:"post", contentType:"application/json",
      headers:{"x-api-key":apiKey,"anthropic-version":"2023-06-01"},
      payload:JSON.stringify({model:CLAUDE_MODEL,max_tokens:700,messages:[{role:"user",content:buildTodayRecommendationPrompt(body)}]}),
      muteHttpExceptions:true
    });
    if (response.getResponseCode() !== 200) return jsonResponse({success:false,error:"AI recommendation request failed."});
    const data = JSON.parse(response.getContentText());
    const textBlock = data.content && data.content[0] && data.content[0].text;
    if (!textBlock) return jsonResponse({success:false,error:"AI recommendation returned no content."});
    const parsed = parseStylingJson(textBlock);
    if (!parsed) return jsonResponse({success:false,error:"AI recommendation response could not be read."});
    const result = sanitizeTodayRecommendation(parsed,body);
    if (!result.styleDirection || !result.recommendedColour || !result.outfitFormula || !result.whyItWorks) return jsonResponse({success:false,error:"AI recommendation returned incomplete content."});
    return jsonResponse({success:true,recommendation:result});
  } catch (error) {
    return jsonResponse({success:false,error:error.toString()});
  }
}

function isVerifiedUser(uid,idToken) {
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/users/" + encodeURIComponent(uid);
    const response = UrlFetchApp.fetch(url,{method:"get",headers:{"Authorization":"Bearer " + idToken},muteHttpExceptions:true});
    return response.getResponseCode() === 200;
  } catch (error) { return false; }
}

function isVerifiedPremiumUser(uid,idToken) {
  try {
    const url = "https://firestore.googleapis.com/v1/projects/" + FIREBASE_PROJECT_ID + "/databases/(default)/documents/users/" + encodeURIComponent(uid);
    const response = UrlFetchApp.fetch(url,{method:"get",headers:{"Authorization":"Bearer " + idToken},muteHttpExceptions:true});
    if (response.getResponseCode() !== 200) return false;
    const doc = JSON.parse(response.getContentText());
    const fields = doc.fields || {};
    return !!(fields.isPremium && fields.isPremium.booleanValue === true);
  } catch (error) { return false; }
}

function hasAiAccess(uid,idToken) {
  // Pre-launch: every authenticated app account, including Free accounts, can use AI.
  // Production: restore the Premium entitlement check.
  if (PRE_LAUNCH_MODE) return !!uid && !!idToken;
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
  try {
    const uid = body.uid;
    const idToken = body.idToken;
    const faceReference = body.modelImage;
    const bodyReference = body.bodyImage;
    const items = Array.isArray(body.items) ? body.items : [];
    if (!uid || !idToken || !faceReference || !faceReference.data || items.length === 0) return jsonResponse({success:false,error:"Missing model photo or wardrobe items."});
    if (items.length > 6) return jsonResponse({success:false,error:"Choose up to 6 wardrobe pieces."});
    if (!hasAiAccess(uid,idToken)) return jsonResponse({success:false,error:"not_premium"});
    const apiKey = PropertiesService.getScriptProperties().getProperty("GEMINI_API_KEY");
    if (!apiKey) return jsonResponse({success:false,error:"Virtual try-on is not configured. Add GEMINI_API_KEY in Script Properties."});

    const inputParts = [{inline_data:{mime_type:faceReference.mimeType || "image/jpeg",data:faceReference.data}}];
    let hasBodyReference = false;
    if (bodyReference && bodyReference.data) {
      inputParts.push({inline_data:{mime_type:bodyReference.mimeType || "image/jpeg",data:bodyReference.data}});
      hasBodyReference = true;
    }

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
    if (garmentDescriptions.length === 0) return jsonResponse({success:false,error:"The selected wardrobe images could not be loaded.",details:garmentErrors.join("; ")});

    const tib = body.tibModel || {};
    const occasion = body.occasion || "Everyday";
    const brief = typeof body.stylingBrief === "string" ? body.stylingBrief.trim() : "";
    const prompt = "Create a photorealistic PERSONAL VIRTUAL YOU fashion try-on. " +
      "REFERENCE 1 is the user's own face and identity. " +
      (hasBodyReference ? "REFERENCE 2 is the same user's own full-body photo and is the primary body-shape, silhouette and proportion reference. " : "") +
      "All following image references are the user's actual selected wardrobe pieces. " +
      "The output must depict the same person, not a generic model. " +
      "PRESERVE IDENTITY: facial structure, eyes, nose, lips, skin tone, hair and recognizable appearance. " +
      "PRESERVE BODY: shoulder width, torso length, waist, hips, legs, overall silhouette and natural proportions. Never slim, enlarge, lengthen, shorten or otherwise redesign the body. " +
      "Use the measurements only as fit context. " +
      "Dress the person ONLY in the selected wardrobe references. Preserve each garment's actual colour, print, texture, fabric, cut, seams, neckline, sleeves and details. Do not invent replacement clothing, shoes, bags or accessories. " +
      "Occasion: " + occasion + ". " +
      "TiB body shape: " + (tib.bodyShape || "unknown") + ", face shape: " + (tib.faceShape || "unknown") + ", height: " + (tib.heightCm != null ? tib.heightCm : "unknown") + " cm, weight: " + (tib.weightKg != null ? tib.weightKg : "unknown") + " kg, bust: " + (tib.bustCm != null ? tib.bustCm : "unknown") + " cm, waist: " + (tib.waistCm != null ? tib.waistCm : "unknown") + " cm, hips: " + (tib.hipsCm != null ? tib.hipsCm : "unknown") + " cm. " +
      (brief ? "Additional styling brief: " + brief + ". " : "") +
      "Generate one complete full-body fashion image from head to toe when possible, with a natural standing pose, realistic garment fit, folds, shadows and lighting, and a clean editorial background. The final image should read as this exact user wearing their own clothes. " +
      "REFERENCE GARMENTS:\n" + garmentDescriptions.join("\n");

    inputParts.push({text:prompt});
    const endpoint = "https://generativelanguage.googleapis.com/v1/models/" + GEMINI_IMAGE_MODEL + ":generateContent";
    const response = UrlFetchApp.fetch(endpoint,{method:"post",contentType:"application/json",headers:{"x-goog-api-key":apiKey},payload:JSON.stringify({contents:[{parts:inputParts}],generationConfig:{responseModalities:["IMAGE"]}}),muteHttpExceptions:true});
    if (response.getResponseCode() !== 200) {
      let providerMessage = "";
      try { const errorData = JSON.parse(response.getContentText()); providerMessage = errorData.error && errorData.error.message ? errorData.error.message : ""; } catch (error) {}
      return jsonResponse({success:false,error:providerMessage || "Virtual try-on generation failed.",providerStatus:response.getResponseCode()});
    }
    const data = JSON.parse(response.getContentText());
    const imagePart = extractGeneratedImagePart(data);
    if (!imagePart || !imagePart.data) return jsonResponse({success:false,error:"Virtual try-on returned no image."});

    const folder = getVirtualTryOnFolder();
    const blob = Utilities.newBlob(Utilities.base64Decode(imagePart.data),imagePart.mimeType || "image/png","try_on_" + new Date().getTime() + ".png");
    const file = folder.createFile(blob);
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK,DriveApp.Permission.VIEW);
    return jsonResponse({success:true,imageUrl:"https://drive.google.com/uc?export=view&id=" + file.getId(),fileId:file.getId(),provider:GEMINI_IMAGE_MODEL,occasion:occasion,selectedItemCount:items.length,usedBodyReference:hasBodyReference,tibModel:{faceShape:tib.faceShape || "unknown",bodyShape:tib.bodyShape || "unknown"}});
  } catch (error) {
    return jsonResponse({success:false,error:error && error.toString ? error.toString() : "Unknown virtual try-on error."});
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
  return ContentService.createTextOutput(JSON.stringify(data)).setMimeType(ContentService.MimeType.JSON);
}
