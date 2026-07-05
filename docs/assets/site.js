(() => {
  const storageKey = 'songbrief-site-language';
  const languages = ['ja', 'en'];
  let lightboxInstance = null;

  const getSavedLanguage = () => {
    try {
      return window.localStorage.getItem(storageKey);
    } catch {
      return null;
    }
  };

  const saveLanguage = (language) => {
    try {
      window.localStorage.setItem(storageKey, language);
    } catch {
      // Language switching still works for the current page if storage is unavailable.
    }
  };

  const getInitialLanguage = () => {
    const saved = getSavedLanguage();
    if (languages.includes(saved)) {
      return saved;
    }
    return window.navigator.language.toLowerCase().startsWith('ja') ? 'ja' : 'en';
  };

  const setText = (element, language) => {
    const value = language === 'ja' ? element.dataset.i18nJa : element.dataset.i18nEn;
    if (value) {
      element.textContent = value;
    }
  };

  const setAriaLabel = (element, language) => {
    const value =
      language === 'ja' ? element.dataset.i18nAriaJa : element.dataset.i18nAriaEn;
    if (value) {
      element.setAttribute('aria-label', value);
    }
  };

  const setMedia = (element, language) => {
    const value = language === 'ja' ? element.dataset.mediaJa : element.dataset.mediaEn;
    if (!value) {
      return;
    }

    if (element.tagName === 'IMG') {
      element.setAttribute('src', value);
      return;
    }

    if (element.tagName === 'A') {
      element.setAttribute('href', value);
    }
  };

  const refreshLightbox = () => {
    if (!window.GLightbox) {
      return;
    }

    if (lightboxInstance && typeof lightboxInstance.destroy === 'function') {
      lightboxInstance.destroy();
    }

    lightboxInstance = window.GLightbox({
      selector: '.glightbox',
      loop: true,
      touchNavigation: true,
      zoomable: true,
    });
  };

  const setLanguage = (language) => {
    const nextLanguage = languages.includes(language) ? language : 'ja';
    document.documentElement.lang = nextLanguage;
    document.documentElement.dataset.lang = nextLanguage;
    saveLanguage(nextLanguage);

    document.querySelectorAll('[data-i18n-ja][data-i18n-en]').forEach((element) => {
      setText(element, nextLanguage);
    });

    document.querySelectorAll('[data-i18n-aria-ja][data-i18n-aria-en]').forEach((element) => {
      setAriaLabel(element, nextLanguage);
    });

    document.querySelectorAll('[data-media-ja][data-media-en]').forEach((element) => {
      setMedia(element, nextLanguage);
    });

    document.querySelectorAll('[data-lang-panel]').forEach((element) => {
      element.hidden = element.dataset.langPanel !== nextLanguage;
    });

    document.querySelectorAll('[data-lang-choice]').forEach((button) => {
      const selected = button.dataset.langChoice === nextLanguage;
      button.setAttribute('aria-pressed', selected ? 'true' : 'false');
    });

    refreshLightbox();
  };

  document.addEventListener('DOMContentLoaded', () => {
    setLanguage(getInitialLanguage());

    document.querySelectorAll('[data-lang-choice]').forEach((button) => {
      button.addEventListener('click', () => {
        setLanguage(button.dataset.langChoice);
      });
    });
  });
})();
