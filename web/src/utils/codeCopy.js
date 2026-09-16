import hljs from 'highlight.js';

function highlightBlock(el) {
  if (!el || el.dataset.hljsDone) return;
  // skip if already contains hljs token spans
  if (el.querySelector && el.querySelector('[class*="hljs-"]')) {
    el.dataset.hljsDone = '1';
    el.classList.add('hljs');
    return;
  }
  const raw = el.textContent || '';
  if (!raw.trim()) return;
  // detect language hint from class or data-language
  const hint = (el.getAttribute('data-language') || el.className.match(/language-(\w+)/)?.[1] || '').toLowerCase();
  try {
    let result = null;
    if (hint && hljs.getLanguage(hint)) {
      result = hljs.highlight(raw, { language: hint, ignoreIllegals: true });
    } else {
      result = hljs.highlightAuto(raw);
    }
    if (result && result.value && result.value !== raw) {
      el.innerHTML = result.value;
      el.classList.add('hljs');
      if (result.language) el.dataset.language = result.language;
    } else {
      // fallback to element API (handles <pre><code> structure)
      try { hljs.highlightElement(el); } catch {}
    }
    el.dataset.hljsDone = '1';
  } catch {
    try { hljs.highlightElement(el); el.dataset.hljsDone = '1'; } catch {}
  }
}

export function enhanceCodeBlocks(container) {
  if (!container || !container.querySelectorAll) return;
  // support Quill 1 (pre.ql-syntax) + Quill 2 (div.ql-code-block-container / div.ql-code-block) + plain pre
  const pres = container.querySelectorAll('pre, div.ql-code-block');
  pres.forEach((pre) => {
    const isCodeLine = pre.classList.contains('ql-code-block');
    const target = isCodeLine ? pre : pre;
    // highlight first (before wrapping, so copy grabs raw text correctly via textContent still)
    highlightBlock(target);

    if (pre.dataset.copyEnhanced) return;
    pre.dataset.copyEnhanced = '1';
    // avoid double-wrapper if already inside
    if (pre.parentElement && pre.parentElement.classList.contains('code-block-wrapper')) return;
    const wrapper = document.createElement('div');
    wrapper.className = 'code-block-wrapper';
    // handle ql-code-block-container case: wrap each line individually? keep wrapper for pre only
    if (isCodeLine) {
      // for single code line, still wrap
      pre.style.position = 'relative';
    }
    try {
      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);
    } catch { return; }
    pre.style.margin = '0';
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'code-copy-btn';
    btn.textContent = 'Copy';
    btn.addEventListener('click', async () => {
      const text = pre.innerText || pre.textContent || '';
      try {
        await navigator.clipboard.writeText(text);
        btn.textContent = 'Copied!';
        btn.classList.add('copied');
        setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 1500);
      } catch {
        const ta = document.createElement('textarea');
        ta.value = text; document.body.appendChild(ta); ta.select();
        try { document.execCommand('copy'); btn.textContent = 'Copied!'; setTimeout(()=>{btn.textContent='Copy';},1500);} catch {}
        ta.remove();
      }
    });
    wrapper.appendChild(btn);
  });

  // also handle container wrapper for Quill 2 grouped blocks -> stitch highlight across lines
  const containers = container.querySelectorAll('div.ql-code-block-container');
  containers.forEach((cont) => {
    if (cont.dataset.hljsDone) return;
    const lines = cont.querySelectorAll('div.ql-code-block');
    if (lines.length === 0) return;
    // if any line already highlighted, mark done
    if (cont.querySelector('[class*="hljs-"]')) { cont.dataset.hljsDone='1'; return; }
    const fullText = Array.from(lines).map(l => l.textContent).join('\n');
    if (!fullText.trim()) return;
    try {
      const result = hljs.highlightAuto(fullText);
      if (result && result.value) {
        // distribute highlighted html back per line (simple split by \n)
        const highlightedLines = result.value.split('\n');
        lines.forEach((line, idx) => {
          line.innerHTML = highlightedLines[idx] || line.textContent;
          line.classList.add('hljs');
        });
        cont.dataset.hljsDone='1';
        cont.classList.add('hljs');
      }
    } catch {}
  });
}
