/**
 * Learning Kanban Native Integration for Homepage
 */

function getApiBase() {
    const host = window.location.hostname;
    if (host === 'localhost' || host.endsWith('.localhost')) {
        return `http://learning.localhost`;
    }
    return `https://learning.arch-services.mywire.org`;
}

const API_BASE = getApiBase();

async function fetchCourses() {
    try {
        const response = await fetch(`${API_BASE}/api/courses`);
        if (!response.ok) return [];
        return await response.json();
    } catch (e) {
        console.error("Failed to fetch courses", e);
        return [];
    }
}

async function updateCourseStatus(courseId, newStatus) {
    try {
        const res = await fetch(`${API_BASE}/api/courses`);
        const courses = await res.json();
        const course = courses.find(c => c.id == courseId);
        if (!course) return;

        course.status = newStatus;

        await fetch(`${API_BASE}/api/courses/${courseId}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(course)
        });
    } catch (e) {
        console.error("Failed to update course", e);
    }
}

function createKanbanCard(course) {
    return `
        <div class="hp-kanban-card" draggable="true" data-id="${course.id}">
            <div class="hp-kanban-card-title">${course.title}</div>
            <div class="hp-kanban-card-desc">${course.description || ''}</div>
            <div class="hp-kanban-card-links">
                <a href="${course.main_link}" target="_blank">Hub ↗</a>
                ${course.last_link ? `<a href="${course.last_link}" target="_blank">Milestone ↗</a>` : ''}
            </div>
        </div>
    `;
}

async function renderKanban() {
    // Find the section by its title
    const sections = document.querySelectorAll('section');
    let container = null;
    for (const section of sections) {
        const h2 = section.querySelector('h2');
        // Match the group name from services.yaml
        if (h2 && h2.textContent.trim() === 'Learning Hub') {
            container = section;
            break;
        }
    }
    
    if (!container) return;

    // Target the list area (usually follows the h2)
    const listArea = container.querySelector('ul') || container.querySelector('.grid') || container.lastElementChild;
    if (!listArea) return;

    // Replace the entire list area with our board
    listArea.outerHTML = `
        <div class="hp-kanban-board">
            <div class="hp-kanban-col" data-status="WIP">
                <h3>🚀 In Progress</h3>
                <div class="hp-kanban-list"></div>
            </div>
            <div class="hp-kanban-col" data-status="Planning">
                <h3>📅 Planning</h3>
                <div class="hp-kanban-list"></div>
            </div>
            <div class="hp-kanban-col" data-status="Archive">
                <h3>📦 Archive</h3>
                <div class="hp-kanban-list"></div>
            </div>
        </div>
    `;

    const courses = await fetchCourses();
    const board = container.querySelector('.hp-kanban-board');
    
    courses.forEach(course => {
        const col = board.querySelector(`.hp-kanban-col[data-status="${course.status}"] .hp-kanban-list`);
        if (col) {
            col.innerHTML += createKanbanCard(course);
        }
    });

    // Add Drag & Drop Listeners
    const cards = board.querySelectorAll('.hp-kanban-card');
    cards.forEach(card => {
        card.addEventListener('dragstart', (e) => {
            e.dataTransfer.setData('text/plain', card.dataset.id);
            card.classList.add('dragging');
        });
        card.addEventListener('dragend', () => card.classList.remove('dragging'));
    });

    const cols = board.querySelectorAll('.hp-kanban-col');
    cols.forEach(col => {
        col.addEventListener('dragover', (e) => e.preventDefault());
        col.addEventListener('drop', async (e) => {
            e.preventDefault();
            const id = e.dataTransfer.getData('text/plain');
            const status = col.dataset.status;
            await updateCourseStatus(id, status);
            renderKanban(); // Re-render
        });
    });
}

// Initial detection and observer for React re-renders
let debounceTimer;
const observer = new MutationObserver(() => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const target = document.querySelector('h2');
        if (target && !document.querySelector('.hp-kanban-board')) {
            renderKanban();
        }
    }, 200);
});

observer.observe(document.body, { childList: true, subtree: true });
renderKanban();
