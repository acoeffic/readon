// Écouter les messages du popup
chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === 'scrapeKindle') {
    scrapeKindleData()
      .then(data => sendResponse({ success: true, data }))
      .catch(error => sendResponse({ success: false, error: error.message }));
    return true;
  }
});

async function scrapeKindleData() {
  console.log('🚀 Début du scraping Kindle...');
  
  // Vérifier qu'on est sur notebook
  if (!window.location.href.includes('/notebook')) {
    throw new Error('Vous devez être sur read.amazon.com/notebook');
  }
  
  // Attendre que la page soit chargée
  await waitForElement('.kp-notebook-library-each-book', 10000);
  
  const bookElements = document.querySelectorAll('.kp-notebook-library-each-book');
  console.log(`📚 ${bookElements.length} livres trouvés`);
  
  const books = [];
  let totalHighlights = 0;

  // Scraper jusqu'à 10 livres
  for (let i = 0; i < Math.min(10, bookElements.length); i++) {
    const bookEl = bookElements[i];
    
    try {
      const titleEl = bookEl.querySelector('.kp-notebook-searchable');
      const authorEls = bookEl.querySelectorAll('.kp-notebook-searchable');
      const authorEl = authorEls[1];
      const coverEl = bookEl.querySelector('img');
      
      const book = {
        id: bookEl.getAttribute('id') || `book-${i}`,
        title: titleEl?.textContent?.trim() || 'Unknown',
        author: authorEl?.textContent?.trim() || 'Unknown',
        cover: coverEl?.src || '',
        highlights: [],
        scrapedAt: new Date().toISOString(),
        progress: null,
        progressPercentage: null
      };
      
      // Cliquer sur le livre
      bookEl.click();
      await sleep(3000);
      
      // Extraire les highlights avec les nouveaux sélecteurs
      const highlightEls = document.querySelectorAll('.kp-notebook-highlight');
      console.log(`📝 ${highlightEls.length} highlights détectés pour ${book.title}`);
      
      highlightEls.forEach(highlightEl => {
        const textEl = highlightEl.querySelector('#highlight') || 
                       highlightEl.querySelector('span.a-size-base-plus');
        
        if (textEl && textEl.textContent?.trim()) {
          book.highlights.push({
            text: textEl.textContent.trim(),
            location: '',
            note: null
          });
        }
      });
      
      book.highlightCount = book.highlights.length;
      totalHighlights += book.highlightCount;
      
      console.log(`✅ ${book.title}: ${book.highlightCount} highlights`);
      
      books.push(book);
      
      // Retour à la liste
      const backButton = document.querySelector('.kp-notebook-back-to-library');
      if (backButton) {
        backButton.click();
      } else {
        window.scrollTo(0, 0);
      }
      
      await sleep(3000);
      
    } catch (error) {
      console.error(`❌ Erreur pour le livre ${i}:`, error);
    }
  }
  
  console.log(`✅ Scraping terminé: ${books.length} livres, ${totalHighlights} highlights`);
  
  return {
    books,
    totalHighlights,
    scrapedAt: new Date().toISOString()
  };
}

function waitForElement(selector, timeout = 5000) {
  return new Promise((resolve, reject) => {
    const element = document.querySelector(selector);
    if (element) {
      resolve(element);
      return;
    }

    const observer = new MutationObserver(() => {
      const element = document.querySelector(selector);
      if (element) {
        observer.disconnect();
        resolve(element);
      }
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    setTimeout(() => {
      observer.disconnect();
      reject(new Error(`Timeout: ${selector} not found`));
    }, timeout);
  });
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

console.log('📚 Kindle Sync Extension chargée');