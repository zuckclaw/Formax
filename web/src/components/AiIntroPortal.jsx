import React, { useState, useEffect } from 'react';

export default function AiIntroPortal({ onComplete }) {
  const [stage, setStage] = useState('active'); // 'active' | 'fading' | 'done'

  useEffect(() => {
    // Phase 1: Reveal & Shimmer (~950ms)
    const fadeTimer = setTimeout(() => {
      setStage('fading');
    }, 950);

    // Phase 2: Fade out & Page Reveal (~1350ms total)
    const doneTimer = setTimeout(() => {
      setStage('done');
      if (onComplete) onComplete();
    }, 1350);

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
      className={`ai-portal-overlay ${stage === 'fading' ? 'portal-fade-out' : ''}`}
      onClick={handleSkip}
      role="button"
      tabIndex={0}
      title="Klik untuk lewati intro"
    >
      {/* Aurora Mesh Glow Center */}
      <div className="ai-portal-aurora">
        <div className="ai-portal-glow glow-blue" />
        <div className="ai-portal-glow glow-cyan" />
        <div className="ai-portal-glow glow-purple" />
      </div>

      {/* Grid Pattern Effect */}
      <div className="ai-portal-grid-bg" />

      {/* Main Kinetic Typography Box */}
      <div className="ai-portal-content">
        <div className="ai-portal-tagline-wrap">
          <span className="ai-portal-sparkle">✦</span>
          <span className="ai-portal-tagline">SMART FORM ENGINE</span>
          <span className="ai-portal-sparkle">✦</span>
        </div>

        <div className="ai-portal-title-container">
          <h1 className="ai-portal-title">
            <span className="ai-portal-char">F</span>
            <span className="ai-portal-char">O</span>
            <span className="ai-portal-char">R</span>
            <span className="ai-portal-char">M</span>
            <span className="ai-portal-char">A</span>
            <span className="ai-portal-char">X</span>
            <span className="ai-portal-ai-badge">AI</span>
          </h1>
          <div className="ai-portal-shimmer-sweep" />
        </div>

        <div className="ai-portal-subtitle-wrap">
          <div className="ai-portal-line" />
          <p className="ai-portal-subtext">NEURAL FORM ARCHITECT</p>
          <div className="ai-portal-line" />
        </div>
      </div>

      <div className="ai-portal-skip-hint">
        <span>Tekan layar untuk lewati</span>
      </div>
    </div>
  );
}
