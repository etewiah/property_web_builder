// PWB Editor Client Script
// Injected into the public site when in edit mode

document.addEventListener('DOMContentLoaded', () => {
  console.log("PWB Editor Client Loaded");

  // Add hover effect to editable elements
  // We assume editable elements have data-pwb-page-part attribute
  // This attribute should be added by the page_part helper
  
  const editableElements = document.querySelectorAll('[data-pwb-page-part]');
  
  editableElements.forEach(el => {
    el.style.cursor = 'pointer';
    el.style.outline = '2px dashed transparent';
    el.style.transition = 'outline 0.2s';
    
    el.addEventListener('mouseover', (e) => {
      e.stopPropagation();
      el.style.outline = '2px dashed #3b82f6';
    });
    
    el.addEventListener('mouseout', (e) => {
      e.stopPropagation();
      el.style.outline = '2px dashed transparent';
    });
    
    el.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      
      const pagePartKey = el.getAttribute('data-pwb-page-part');
      
      // Send message to parent (editor shell)
      window.parent.postMessage({
        type: 'pwb:element:selected',
        payload: {
          key: pagePartKey,
          content: el.innerHTML
        }
      }, '*');
    });
  });
});
