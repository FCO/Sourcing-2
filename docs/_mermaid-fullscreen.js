/**
 * Mermaid Fullscreen/Zoom Functionality
 * 
 * Provides click-to-expand fullscreen mode for mermaid diagrams
 * with zoom support and Escape key to close.
 */

(function() {
    'use strict';

    // Wait for DOM and mermaid to be ready
    document.addEventListener('DOMContentLoaded', init);

    function init() {
        // Find all mermaid containers and wrap them
        wrapMermaidDiagrams();
        
        // Listen for new mermaid diagrams being rendered
        document.addEventListener('mermaid-render-finish', wrapMermaidDiagrams);
        
        // Also check after a short delay for initial renders
        setTimeout(wrapMermaidDiagrams, 500);
    }

    function wrapMermaidDiagrams() {
        // Find mermaid divs that haven't been wrapped yet
        const mermaidDivs = document.querySelectorAll('.mermaid:not([data-mermaid-wrapped])');
        
        mermaidDivs.forEach(function(div) {
            wrapMermaidDiagram(div);
        });
    }

    function wrapMermaidDiagram(div) {
        // Mark as wrapped to avoid duplicate processing
        div.setAttribute('data-mermaid-wrapped', 'true');
        
        // Find the actual svg element inside
        const svg = div.querySelector('svg');
        if (!svg) {
            // Try again after a short delay (mermaid might still be rendering)
            setTimeout(function() {
                const retrySvg = div.querySelector('svg');
                if (retrySvg) {
                    enhanceDiagram(div, retrySvg);
                }
            }, 500);
            return;
        }
        
        enhanceDiagram(div, svg);
    }

    function enhanceDiagram(div, svg) {
        // Make the container clickable
        div.classList.add('mermaid-expandable');
        
        // Add click handler
        div.addEventListener('click', function(e) {
            e.preventDefault();
            openFullscreen(div, svg);
        });
        
        // Add keyboard hint
        div.setAttribute('tabindex', '0');
        div.setAttribute('role', 'button');
        div.setAttribute('aria-label', 'Click to expand diagram');
        
        div.addEventListener('keydown', function(e) {
            if (e.key === 'Enter' || e.key === ' ') {
                e.preventDefault();
                openFullscreen(div, svg);
            }
        });
    }

    function openFullscreen(div, svg) {
        // Create fullscreen overlay
        const overlay = document.createElement('div');
        overlay.className = 'mermaid-fullscreen-overlay';
        overlay.setAttribute('data-mermaid-fullscreen', 'true');
        
        // Create container for the diagram
        const container = document.createElement('div');
        container.className = 'mermaid-fullscreen-container';
        
        // Create header with controls
        const header = document.createElement('div');
        header.className = 'mermaid-fullscreen-header';
        
        const title = document.createElement('span');
        title.className = 'mermaid-fullscreen-title';
        title.textContent = 'Diagram';
        
        const controls = document.createElement('div');
        controls.className = 'mermaid-fullscreen-controls';
        
        const zoomInBtn = document.createElement('button');
        zoomInBtn.className = 'mermaid-fullscreen-btn';
        zoomInBtn.setAttribute('title', 'Zoom In');
        zoomInBtn.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/><line x1="11" y1="8" x2="11" y2="14"/><line x1="8" y1="11" x2="14" y2="11"/></svg>';
        
        const zoomOutBtn = document.createElement('button');
        zoomOutBtn.className = 'mermaid-fullscreen-btn';
        zoomOutBtn.setAttribute('title', 'Zoom Out');
        zoomOutBtn.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/><line x1="8" y1="11" x2="14" y2="11"/></svg>';
        
        const resetBtn = document.createElement('button');
        resetBtn.className = 'mermaid-fullscreen-btn';
        resetBtn.setAttribute('title', 'Reset Zoom');
        resetBtn.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2"><path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/></svg>';
        
        const closeBtn = document.createElement('button');
        closeBtn.className = 'mermaid-fullscreen-btn mermaid-fullscreen-close';
        closeBtn.setAttribute('title', 'Close (Esc)');
        closeBtn.innerHTML = '<svg viewBox="0 0 24 24" width="20" height="20" stroke="currentColor" fill="none" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>';
        
        controls.appendChild(zoomInBtn);
        controls.appendChild(zoomOutBtn);
        controls.appendChild(resetBtn);
        controls.appendChild(closeBtn);
        
        header.appendChild(title);
        header.appendChild(controls);
        
        // Create scrollable diagram area
        const diagramWrapper = document.createElement('div');
        diagramWrapper.className = 'mermaid-fullscreen-diagram';
        
        // Clone the SVG and append it
        const clonedSvg = svg.cloneNode(true);
        clonedSvg.classList.add('mermaid-zoomable');
        diagramWrapper.appendChild(clonedSvg);
        
        container.appendChild(header);
        container.appendChild(diagramWrapper);
        overlay.appendChild(container);
        
        document.body.appendChild(overlay);
        document.body.classList.add('mermaid-fullscreen-open');
        
        // Zoom state
        let scale = 1;
        let translateX = 0;
        let translateY = 0;
        let isDragging = false;
        let startX, startY;
        
        function updateTransform() {
            clonedSvg.style.transform = `translate(${translateX}px, ${translateY}px) scale(${scale})`;
        }
        
        function resetZoom() {
            scale = 1;
            translateX = 0;
            translateY = 0;
            updateTransform();
        }
        
        function zoomIn() {
            scale = Math.min(scale + 0.25, 4);
            updateTransform();
        }
        
        function zoomOut() {
            scale = Math.max(scale - 0.25, 0.25);
            updateTransform();
        }
        
        // Event handlers
        zoomInBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            zoomIn();
        });
        
        zoomOutBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            zoomOut();
        });
        
        resetBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            resetZoom();
        });
        
        closeBtn.addEventListener('click', function(e) {
            e.stopPropagation();
            closeFullscreen();
        });
        
        overlay.addEventListener('click', function(e) {
            if (e.target === overlay) {
                closeFullscreen();
            }
        });
        
        // Mouse wheel zoom
        diagramWrapper.addEventListener('wheel', function(e) {
            e.preventDefault();
            if (e.deltaY < 0) {
                zoomIn();
            } else {
                zoomOut();
            }
        }, { passive: false });
        
        // Drag to pan
        diagramWrapper.addEventListener('mousedown', function(e) {
            isDragging = true;
            startX = e.clientX - translateX;
            startY = e.clientY - translateY;
            diagramWrapper.style.cursor = 'grabbing';
        });
        
        document.addEventListener('mousemove', function(e) {
            if (!isDragging) return;
            translateX = e.clientX - startX;
            translateY = e.clientY - startY;
            updateTransform();
        });
        
        document.addEventListener('mouseup', function() {
            isDragging = false;
            diagramWrapper.style.cursor = 'grab';
        });
        
        // Touch support for mobile
        let touchStartX, touchStartY, initialScale;
        
        diagramWrapper.addEventListener('touchstart', function(e) {
            if (e.touches.length === 1) {
                isDragging = true;
                touchStartX = e.touches[0].clientX - translateX;
                touchStartY = e.touches[0].clientY - translateY;
            } else if (e.touches.length === 2) {
                isDragging = false;
                initialScale = scale;
            }
        });
        
        diagramWrapper.addEventListener('touchmove', function(e) {
            e.preventDefault();
            if (e.touches.length === 1 && isDragging) {
                translateX = e.touches[0].clientX - touchStartX;
                translateY = e.touches[0].clientY - touchStartY;
                updateTransform();
            } else if (e.touches.length === 2) {
                const touchDistance = Math.hypot(
                    e.touches[0].clientX - e.touches[1].clientX,
                    e.touches[0].clientY - e.touches[1].clientY
                );
                if (initialScale) {
                    const newScale = initialScale * (touchDistance / 200);
                    scale = Math.max(0.25, Math.min(4, newScale));
                    updateTransform();
                }
            }
        }, { passive: false });
        
        diagramWrapper.addEventListener('touchend', function() {
            isDragging = false;
            initialScale = null;
        });
        
        function closeFullscreen() {
            document.body.classList.remove('mermaid-fullscreen-open');
            overlay.remove();
        }
        
        // Escape key to close
        function handleKeydown(e) {
            if (e.key === 'Escape') {
                closeFullscreen();
                document.removeEventListener('keydown', handleKeydown);
            }
        }
        
        document.addEventListener('keydown', handleKeydown);
        
        // Initial transform
        updateTransform();
    }
})();
