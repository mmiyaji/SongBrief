(() => {
  const storageKey = 'songbrief-site-language';
  const languages = ['ja', 'en'];

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

    document.querySelectorAll('[data-lang-panel]').forEach((element) => {
      element.hidden = element.dataset.langPanel !== nextLanguage;
    });

    document.querySelectorAll('[data-lang-choice]').forEach((button) => {
      const selected = button.dataset.langChoice === nextLanguage;
      button.setAttribute('aria-pressed', selected ? 'true' : 'false');
    });
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
