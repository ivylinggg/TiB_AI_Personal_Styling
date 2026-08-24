// TiB AI Personal Styling — Virtual Try-On backend patch
//
// Add the routing block shown below inside doPost(), immediately after the
// existing aiStyling routing block:
//
// if (body.action === "virtualTryOn") {
//   return handleVirtualTryOn(body);
// }
//
// Add GEMINI_IMAGE_MODEL near the existing CLAUDE_MODEL constant, and add
// GEMINI_API_KEY to Apps Script Project Settings > Script Properties.
//
// This patch relies on the existing isVerifiedPremiumUser() and jsonResponse()
// helpers already present in Code.gs.

const GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image";

function handleVirtualTryOn(body) {
  try {
    const uid = body.uid;
    const idToken = body.idToken;
    const modelImage = body.modelImage;
    const items = Array.isArray(body.items) ? body.items : [];

    if (!uid || !idToken || !modelImage || !modelImage.data || items.length === 0) {
      return jsonResponse({
        success: false,
        error: "Missing model photo or wardrobe items."
      });
    }

    if (items.length > 5) {
      return jsonResponse({
        success: false,
        error: "Choose up to 5 wardrobe pieces."
      });
    }

    if (!isVerifiedPremiumUser(uid, idToken)) {
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
        "Reference garment " + (i + 1) + ": " +
        (item.category || "item") + ", " +
        (item.name || "unnamed") + ", colour " +
        (item.colour || "unknown") + ", style " +
        (item.style || "unknown")
      );
    }

    if (garmentDescriptions.length === 0) {
      return jsonResponse({
        success: false,
        error: "The selected wardrobe images could not be loaded."
      });
    }

    const occasion = body.occasion || "Everyday";
    const prompt =
      "Create a photorealistic virtual fashion try-on using the provided reference images. " +
      "The FIRST image is the user's model reference. The following images are the user's actual wardrobe garments. " +
      "Dress the same person in the first image in the selected garments. " +
      "Preserve the person's identity, facial features, skin tone, hair, body proportions and overall appearance. " +
      "Do not invent different garments. Use the exact garments shown in the wardrobe reference images, with their real colours, patterns, materials and silhouettes. " +
      "Combine the garments into one coherent outfit appropriate for the " + occasion + " occasion. " +
      "Generate a realistic full-body fashion photograph, natural pose, realistic garment fit, folds, shadows and lighting. " +
      "Do not add logos, text or extra accessories that are not present in the references. " +
      "Keep the result tasteful and suitable for a personal styling application.\n\n" +
      garmentDescriptions.join("\n");

    inputParts.push({ text: prompt });

    const response = UrlFetchApp.fetch(
      "https://generativelanguage.googleapis.com/v1/models/" + GEMINI_IMAGE_MODEL + ":generateContent",
      {
        method: "post",
        contentType: "application/json",
        headers: {
          "x-goog-api-key": apiKey
        },
        payload: JSON.stringify({
          contents: [{ parts: inputParts }],
          generationConfig: {
            responseModalities: ["IMAGE"]
          }
        }),
        muteHttpExceptions: true
      }
    );

    if (response.getResponseCode() !== 200) {
      return jsonResponse({
        success: false,
        error: "Virtual try-on generation failed.",
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
    file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);

    return jsonResponse({
      success: true,
      imageUrl: "https://drive.google.com/uc?export=view&id=" + file.getId(),
      fileId: file.getId(),
      provider: GEMINI_IMAGE_MODEL
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      error: error.toString()
    });
  }
}

function fetchRemoteImage(url) {
  try {
    if (typeof url !== "string" || !/^https:\/\//i.test(url)) return null;

    const response = UrlFetchApp.fetch(url, {
      method: "get",
      muteHttpExceptions: true
    });

    if (response.getResponseCode() !== 200) return null;

    const blob = response.getBlob();
    const mimeType = blob.getContentType() || "image/jpeg";
    if (mimeType.indexOf("image/") !== 0) return null;

    return {
      mimeType: mimeType,
      data: Utilities.base64Encode(blob.getBytes())
    };
  } catch (_) {
    return null;
  }
}

function extractGeneratedImagePart(data) {
  try {
    const candidates = data.candidates || [];
    for (let i = 0; i < candidates.length; i++) {
      const parts = candidates[i].content && candidates[i].content.parts;
      if (!Array.isArray(parts)) continue;

      for (let j = 0; j < parts.length; j++) {
        const inlineData = parts[j].inlineData || parts[j].inline_data;
        if (inlineData && inlineData.data) {
          return {
            data: inlineData.data,
            mimeType: inlineData.mimeType || inlineData.mime_type || "image/png"
          };
        }
      }
    }
  } catch (_) {}

  return null;
}

function getVirtualTryOnFolder() {
  const parent = DriveApp.getFolderById(PROFILE_FOLDER_ID);
  const folders = parent.getFoldersByName("virtual_try_on");
  return folders.hasNext() ? folders.next() : parent.createFolder("virtual_try_on");
}
