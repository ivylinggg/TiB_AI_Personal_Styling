// TiB pre-launch Virtual Try-On override.
// This file intentionally overrides the legacy handleVirtualTryOn() in Code.gs
// without changing the existing backend routes or other AI functions.
// The override keeps Free-user access in PRE_LAUNCH_MODE and uses both the
// user's face and body references before applying the selected wardrobe.

function handleVirtualTryOn(body) {
  try {
    const uid = body.uid;
    const idToken = body.idToken;
    const modelImage = body.modelImage;
    const bodyImage = body.bodyImage;
    const items = Array.isArray(body.items) ? body.items : [];

    if (!uid || !idToken || !modelImage || !modelImage.data || items.length === 0) {
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

    if (!hasAiAccess(uid, idToken)) {
      return jsonResponse({
        success: false,
        error: "not_premium"
      });
    }

    const apiKey = PropertiesService.getScriptProperties().getProperty("GEMINI_API_KEY");
    if (!apiKey) {
      return jsonResponse({
        success: false,
        error: "Virtual try-on is not configured. Add GEMINI_API_KEY in Script Properties."
      });
    }

    // Reference order is deliberate:
    // 1. Face = identity
    // 2. Body = real silhouette / proportions / appearance
    // 3+. Actual wardrobe images
    const inputParts = [
      {
        inline_data: {
          mime_type: modelImage.mimeType || "image/jpeg",
          data: modelImage.data
        }
      }
    ];

    const hasBodyReference = !!(bodyImage && bodyImage.data);
    if (hasBodyReference) {
      inputParts.push({
        inline_data: {
          mime_type: bodyImage.mimeType || "image/jpeg",
          data: bodyImage.data
        }
      });
    }

    const garmentDescriptions = [];

    for (let i = 0; i < items.length; i++) {
      const item = items[i] || {};
      if (!item.imageUrl) continue;

      const garment = fetchRemoteImage(item.imageUrl);
      if (!garment) continue;

      inputParts.push({
        inline_data: {
          mime_type: garment.mimeType,
          data: garment.data
        }
      });

      garmentDescriptions.push(
        "Reference garment " + (garmentDescriptions.length + 1) +
        ": category=" + (item.category || "item") +
        ", name=" + (item.name || "unnamed") +
        ", colour=" + (item.colour || "unknown") +
        ", style=" + (item.style || "unknown")
      );
    }

    if (garmentDescriptions.length === 0) {
      return jsonResponse({
        success: false,
        error: "The selected wardrobe images could not be loaded."
      });
    }

    const occasion = body.occasion || "Everyday";
    const tibModel = body.tibModel || {};
    const stylingBrief = typeof body.stylingBrief === "string" ? body.stylingBrief.trim() : "";

    const prompt =
      "Create a photorealistic AI virtual fashion model of the USER using the supplied reference images. " +
      "This is a personal virtual try-on, not a generic fashion model. " +
      "REFERENCE IMAGE 1 is the user's face and identity reference. " +
      (hasBodyReference
        ? "REFERENCE IMAGE 2 is the user's own full-body reference and is the primary silhouette, body-proportion and appearance reference. "
        : "No full-body reference was supplied, so use the supplied TiB measurements and body-shape context without inventing an idealized body. ") +
      "All later image references are the user's actual wardrobe items. " +
      "\n\nIDENTITY RULES:\n" +
      "Keep the same recognizable person: facial structure, eyes, nose, lips, skin tone, hair, age appearance and overall identity. " +
      "Do not replace the person with a model. Do not beautify the face into a different person. " +
      "\n\nBODY RULES:\n" +
      "Preserve the user's natural body shape, proportions, shoulder width, torso length, waist, hips and overall silhouette as represented by the body reference and measurements. " +
      "Do not slim, enlarge, lengthen, shorten or reshape the body into an idealized fashion body. " +
      "The measurements are fit context, not permission to alter the body. " +
      "\n\nTIB PERSONAL FIT CONTEXT:\n" +
      "Face shape: " + (tibModel.faceShape || "unknown") + "\n" +
      "Body shape: " + (tibModel.bodyShape || "unknown") + "\n" +
      "Height: " + (tibModel.height != null ? tibModel.height : "unknown") + " cm\n" +
      "Weight: " + (tibModel.weight != null ? tibModel.weight : "unknown") + " kg\n" +
      "Bust: " + (tibModel.bust != null ? tibModel.bust : "unknown") + " cm\n" +
      "Waist: " + (tibModel.waist != null ? tibModel.waist : "unknown") + " cm\n" +
      "Hips: " + (tibModel.hips != null ? tibModel.hips : "unknown") + " cm\n" +
      "\n\nOCCASION:\n" + occasion +
      (stylingBrief ? "\n\nSTYLING BRIEF:\n" + stylingBrief : "") +
      "\n\nWARDROBE RULES:\n" +
      "Dress the same user in ONLY the selected wardrobe references. " +
      "Preserve each garment's real colour, pattern, fabric, texture, silhouette, neckline, sleeves, seams and important details. " +
      "Do not replace garments with similar invented clothing. Do not invent shoes, bags, jewellery or accessories. " +
      "If an item is a shoe, show the actual selected shoe on the user's feet. " +
      "\n\nCOMPOSITION:\n" +
      "Generate one complete full-body fashion image whenever possible, from head to toe, with a natural standing pose. " +
      "Make clothing fit naturally on the user's actual proportions with realistic folds, tension, shadows and lighting. " +
      "Use a clean, realistic editorial background. " +
      "The final image should immediately read as: 'this is me wearing my own clothes'. " +
      "\n\nREFERENCE GARMENTS:\n" + garmentDescriptions.join("\n");

    inputParts.push({ text: prompt });

    const endpoint =
      "https://generativelanguage.googleapis.com/v1/models/" +
      GEMINI_IMAGE_MODEL +
      ":generateContent";

    const payload = {
      contents: [{ parts: inputParts }],
      generationConfig: {
        responseModalities: ["IMAGE"]
      }
    };

    const response = UrlFetchApp.fetch(endpoint, {
      method: "post",
      contentType: "application/json",
      headers: { "x-goog-api-key": apiKey },
      payload: JSON.stringify(payload),
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) {
      let providerMessage = "";
      try {
        const errorData = JSON.parse(response.getContentText());
        providerMessage = errorData.error && errorData.error.message
          ? errorData.error.message
          : "";
      } catch (_) {}

      return jsonResponse({
        success: false,
        error: providerMessage || "Virtual try-on generation failed.",
        providerStatus: response.getResponseCode()
      });
    }

    const data = JSON.parse(response.getContentText());
    const imagePart = extractGeneratedImagePart(data);

    if (!imagePart || !imagePart.data) {
      return jsonResponse({
        success: false,
        error: "Virtual try-on returned no image."
      });
    }

    const folder = getVirtualTryOnFolder();
    const bytes = Utilities.base64Decode(imagePart.data);
    const blob = Utilities.newBlob(
      bytes,
      imagePart.mimeType || "image/png",
      "try_on_" + new Date().getTime() + ".png"
    );
    const file = folder.createFile(blob);

    file.setSharing(
      DriveApp.Access.ANYONE_WITH_LINK,
      DriveApp.Permission.VIEW
    );

    return jsonResponse({
      success: true,
      imageUrl: "https://drive.google.com/uc?export=view&id=" + file.getId(),
      fileId: file.getId(),
      provider: GEMINI_IMAGE_MODEL,
      occasion: occasion,
      selectedItemCount: items.length,
      usedBodyReference: hasBodyReference,
      tibModel: {
        faceShape: tibModel.faceShape || "unknown",
        bodyShape: tibModel.bodyShape || "unknown"
      }
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error && error.toString
        ? error.toString()
        : "Unknown virtual try-on error."
    });
  }
}
