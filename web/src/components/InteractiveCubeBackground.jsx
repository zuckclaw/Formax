import { useEffect, useRef } from 'react';

const InteractiveCubeBackground = () => {
  const canvasRef = useRef(null);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    let animationFrameId;
    let width = (canvas.width = window.innerWidth);
    let height = (canvas.height = window.innerHeight);

    const mouse = {
      x: width / 2,
      y: height / 2,
      targetX: width / 2,
      targetY: height / 2,
      isHovered: false,
    };

    // Vibrant blue gradient palettes
    const colors = [
      { start: '#2563eb', end: '#60a5fa' }, // Blue
      { start: '#0284c7', end: '#38bdf8' }, // Sky Cyan
      { start: '#4f46e5', end: '#818cf8' }, // Indigo
      { start: '#06b6d4', end: '#67e8f9' }, // Cyan
      { start: '#1d4ed8', end: '#3b82f6' }, // Royal Blue
    ];

    // Trail particles only (following cursor)
    const trail = [];
    const maxTrail = 35;

    const handleMouseMove = (e) => {
      mouse.targetX = e.clientX;
      mouse.targetY = e.clientY;
      mouse.isHovered = true;

      // Spawn trail cubes following mouse
      trail.push({
        x: e.clientX + (Math.random() - 0.5) * 14,
        y: e.clientY + (Math.random() - 0.5) * 14,
        size: Math.random() * 10 + 6,
        vx: (Math.random() - 0.5) * 2,
        vy: (Math.random() - 0.5) * 2,
        angle: Math.random() * Math.PI * 2,
        vAngle: (Math.random() - 0.5) * 0.12,
        alpha: 0.95,
        color: colors[Math.floor(Math.random() * colors.length)],
      });

      if (trail.length > maxTrail) {
        trail.shift();
      }
    };

    const handleMouseLeave = () => {
      mouse.isHovered = false;
    };

    const handleResize = () => {
      if (!canvas) return;
      width = canvas.width = window.innerWidth;
      height = canvas.height = window.innerHeight;
    };

    const handleClick = (e) => {
      // Burst effect on click
      for (let i = 0; i < 18; i++) {
        const angle = (Math.PI * 2 * i) / 18;
        const speed = Math.random() * 4.5 + 2;
        trail.push({
          x: e.clientX,
          y: e.clientY,
          size: Math.random() * 12 + 7,
          vx: Math.cos(angle) * speed,
          vy: Math.sin(angle) * speed,
          angle: Math.random() * Math.PI * 2,
          vAngle: (Math.random() - 0.5) * 0.15,
          alpha: 1,
          color: colors[Math.floor(Math.random() * colors.length)],
        });
      }
    };

    window.addEventListener('mousemove', handleMouseMove);
    window.addEventListener('mouseleave', handleMouseLeave);
    window.addEventListener('resize', handleResize);
    window.addEventListener('click', handleClick);

    const fillRoundRect = (c, x, y, w, h, r) => {
      c.beginPath();
      if (c.roundRect) {
        c.roundRect(x, y, w, h, r);
      } else {
        c.rect(x, y, w, h);
      }
      c.fill();
    };

    const render = () => {
      ctx.clearRect(0, 0, width, height);

      // Smooth mouse lerp
      mouse.x += (mouse.targetX - mouse.x) * 0.18;
      mouse.y += (mouse.targetY - mouse.y) * 0.18;

      // Draw cursor radial glow aura
      if (mouse.isHovered) {
        ctx.save();
        const mouseGrad = ctx.createRadialGradient(mouse.x, mouse.y, 0, mouse.x, mouse.y, 140);
        mouseGrad.addColorStop(0, 'rgba(59, 130, 246, 0.14)');
        mouseGrad.addColorStop(0.5, 'rgba(6, 182, 212, 0.05)');
        mouseGrad.addColorStop(1, 'rgba(37, 99, 235, 0)');
        ctx.fillStyle = mouseGrad;
        ctx.beginPath();
        ctx.arc(mouse.x, mouse.y, 140, 0, Math.PI * 2);
        ctx.fill();
        ctx.restore();
      }

      // Render cursor trail cubes
      for (let i = trail.length - 1; i >= 0; i--) {
        const p = trail[i];
        p.x += p.vx;
        p.y += p.vy;
        p.angle += p.vAngle;
        p.alpha -= 0.024;
        p.size *= 0.96;

        if (p.alpha <= 0 || p.size < 1) {
          trail.splice(i, 1);
          continue;
        }

        ctx.save();
        ctx.translate(p.x, p.y);
        ctx.rotate(p.angle);

        const grad = ctx.createLinearGradient(-p.size / 2, -p.size / 2, p.size / 2, p.size / 2);
        grad.addColorStop(0, p.color.start);
        grad.addColorStop(1, p.color.end);

        ctx.globalAlpha = p.alpha;
        ctx.fillStyle = grad;
        ctx.shadowColor = p.color.start;
        ctx.shadowBlur = 10;

        const radius = Math.min(3, p.size / 3);
        const half = p.size / 2;
        fillRoundRect(ctx, -half, -half, p.size, p.size, radius);

        ctx.restore();
      }

      animationFrameId = requestAnimationFrame(render);
    };

    render();

    return () => {
      window.removeEventListener('mousemove', handleMouseMove);
      window.removeEventListener('mouseleave', handleMouseLeave);
      window.removeEventListener('resize', handleResize);
      window.removeEventListener('click', handleClick);
      cancelAnimationFrame(animationFrameId);
    };
  }, []);

  return (
    <canvas
      ref={canvasRef}
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        width: '100vw',
        height: '100vh',
        pointerEvents: 'none',
        zIndex: 1,
      }}
    />
  );
};

export default InteractiveCubeBackground;
