// Service worker pour l'extension
chrome.runtime.onInstalled.addListener(() => {
  console.log('📚 Kindle Sync Extension installée !');
});

// Écouter les messages
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'syncComplete') {
    // Notification de succès
    chrome.notifications.create({
      type: 'basic',
      iconUrl: 'icons/icon48.png',
      title: 'Kindle Sync',
      message: `${request.booksCount} livres synchronisés !`
    });
  }
});