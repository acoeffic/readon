const syncBtn = document.getElementById('syncBtn');
const statusDiv = document.getElementById('status');
const statsContainer = document.getElementById('statsContainer');
const booksCount = document.getElementById('booksCount');
const highlightsCount = document.getElementById('highlightsCount');

// Charger les stats au démarrage
loadStats();

syncBtn.addEventListener('click', async () => {
  try {
    // Vérifier qu'on est sur la bonne page
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    
    if (!tab.url.includes('read.amazon.com/notebook')) {
      updateStatus('error', '❌ Veuillez aller sur read.amazon.com/notebook');
      return;
    }

    updateStatus('syncing', '🔄 Synchronisation en cours...');
    syncBtn.disabled = true;

    // Envoyer un message au content script pour scraper
    const response = await chrome.tabs.sendMessage(tab.id, { action: 'scrapeKindle' });

    if (response.success) {
      // Envoyer les données au backend
      await sendToBackend(response.data);
      
      updateStatus('success', `✅ ${response.data.books.length} livres synchronisés !`);
      
      // Mettre à jour les stats
      booksCount.textContent = response.data.books.length;
      highlightsCount.textContent = response.data.totalHighlights || 0;
      statsContainer.style.display = 'block';
      
      // Sauvegarder les stats
      chrome.storage.local.set({
        lastSync: new Date().toISOString(),
        booksCount: response.data.books.length,
        highlightsCount: response.data.totalHighlights || 0
      });
      
    } else {
      updateStatus('error', '❌ Erreur : ' + response.error);
    }

  } catch (error) {
    console.error('Erreur sync:', error);
    updateStatus('error', '❌ Erreur de synchronisation');
  } finally {
    syncBtn.disabled = false;
  }
});

async function sendToBackend(data) {
  console.log('📤 Envoi au backend...', data);
  
  try {
    const response = await fetch('https://kindle-backend-clean-production.up.railway.app/api/sync-extension', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(data),
    });

    console.log('📡 Réponse backend status:', response.status);

    if (!response.ok) {
      const errorText = await response.text();
      console.error('❌ Erreur backend:', errorText);
      throw new Error('Erreur backend: ' + response.status);
    }

    const result = await response.json();
    console.log('✅ Backend response:', result);
    return result;
  } catch (error) {
    console.error('❌ Erreur sendToBackend:', error);
    throw error;
  }
}

function updateStatus(type, message) {
  statusDiv.className = `status ${type}`;
  statusDiv.textContent = message;
}

async function loadStats() {
  const data = await chrome.storage.local.get(['booksCount', 'highlightsCount', 'lastSync']);
  
  if (data.booksCount) {
    booksCount.textContent = data.booksCount;
    highlightsCount.textContent = data.highlightsCount || 0;
    statsContainer.style.display = 'block';
    
    const lastSync = new Date(data.lastSync);
    const now = new Date();
    const diffHours = Math.floor((now - lastSync) / (1000 * 60 * 60));
    
    if (diffHours < 1) {
      updateStatus('success', '✅ Synchronisé il y a moins d\'1h');
    } else if (diffHours < 24) {
      updateStatus('success', `✅ Synchronisé il y a ${diffHours}h`);
    } else {
      updateStatus('idle', 'Prêt à synchroniser');
    }
  }
}