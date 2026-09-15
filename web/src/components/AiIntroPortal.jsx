import React, { useState, useEffect } from 'react';
import logoForm4x from '../assets/logo_form4x.png';

export default function AiIntroPortal({ onComplete }) {
  const [stage, setStage] = useState('active'); // 'active' | 'fading' | 'done'

  useEffect(() => {
    // Phase 1: Clean brief display (550ms)
    const fadeTimer = setTimeout(() => {
      setStage('fading');
    }, 550);

    // Phase 2: Fade out & reveal UI (780ms total)
    const doneTimer = setTimeout(() => {
      setStage('done');
      if (onComplete) onComplete();
    }, 780);

    return () => {
      clearTimeout(fadeTimer);
      clearTimeout(doneTimer);
    };
  }, [onComplete]);

  const handleSkip = () => {
    setStage('done');
    if (onComplete) onComplete();
  };

  if (stage === 'done') return null;

  return (
    <div
      className={`ai-clean-portal ${stage === 'fading' ? 'ai-portal-fade-out' : ''}`}
      onClick={handleSkip}
      role="presentation"
    >
      <div className="ai-clean-portal-content">
        <div className="ai-clean-portal-logo-wrap">
          <img src={logoForm4x} alt="Form4x" className="ai-clean-portal-logo" />
        </div>
        <div className="ai-clean-portal-text-row">
          <span className="ai-clean-portal-brand">FORMAX</span>
          <span className="ai-clean-portal-ai-pill">AI</span>
        </div>
        <div className="ai-clean-portal-bar">
          <div className="ai-clean-portal-bar-fill" />
        </div>
      </div>
    </div>
  );
}
