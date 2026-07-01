/**
 * ReadingSorter Hook
 *
 * Provides drag-and-drop reordering functionality for kanji readings.
 * Uses native HTML5 drag and drop API.
 */
const ReadingSorter = {
  mounted() {
    this.container = this.el;
    this.draggedItem = null;

    this.initSortable();
  },

  initSortable() {
    const items = this.container.querySelectorAll('[data-reading-id]');

    items.forEach(item => {
      // Make items draggable
      item.setAttribute('draggable', 'true');

      // Drag start
      item.addEventListener('dragstart', (e) => {
        this.draggedItem = item;
        item.classList.add('opacity-50', 'dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', item.dataset.readingId);
      });

      // Drag end
      item.addEventListener('dragend', () => {
        item.classList.remove('opacity-50', 'dragging');
        this.draggedItem = null;
        this.updateOrder();
      });

      // Drag over
      item.addEventListener('dragover', (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';

        if (this.draggedItem && this.draggedItem !== item) {
          const rect = item.getBoundingClientRect();
          const midpoint = rect.top + rect.height / 2;

          if (e.clientY < midpoint) {
            item.parentNode.insertBefore(this.draggedItem, item);
          } else {
            item.parentNode.insertBefore(this.draggedItem, item.nextSibling);
          }
        }
      });

      // Drag enter
      item.addEventListener('dragenter', (e) => {
        e.preventDefault();
        if (item !== this.draggedItem) {
          item.classList.add('bg-primary/5');
        }
      });

      // Drag leave
      item.addEventListener('dragleave', () => {
        item.classList.remove('bg-primary/5');
      });

      // Drop
      item.addEventListener('drop', (e) => {
        e.preventDefault();
        item.classList.remove('bg-primary/5');
      });
    });

    // Container-level dragover for dropping at the end
    this.container.addEventListener('dragover', (e) => {
      e.preventDefault();

      if (!this.draggedItem) return;

      const afterElement = this.getDragAfterElement(this.container, e.clientY);

      if (afterElement == null) {
        this.container.appendChild(this.draggedItem);
      } else {
        this.container.insertBefore(this.draggedItem, afterElement);
      }
    });
  },

  getDragAfterElement(container, y) {
    const draggableElements = [...container.querySelectorAll('[data-reading-id]:not(.dragging)')];

    return draggableElements.reduce((closest, child) => {
      const box = child.getBoundingClientRect();
      const offset = y - box.top - box.height / 2;

      if (offset < 0 && offset > closest.offset) {
        return { offset: offset, element: child };
      } else {
        return closest;
      }
    }, { offset: Number.NEGATIVE_INFINITY }).element;
  },

  updateOrder() {
    const items = this.container.querySelectorAll('[data-reading-id]');
    const readingIds = Array.from(items).map(item => item.dataset.readingId);

    // Push event to LiveView
    this.pushEvent('reorder_readings', { reading_ids: readingIds });
  },

  updated() {
    // Re-initialize after LiveView update
    this.initSortable();
  }
};

export default ReadingSorter;
