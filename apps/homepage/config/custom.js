/**
 * Learning Kanban Native Integration for Homepage (v4 - Autonomous & Anchorless)
 */

function getApiBase() {
    const host = window.location.hostname;
    if (host === 'localhost' || host.endsWith('.localhost')) {
        return `http://learning.localhost`;
    }
    return `https://learning.arch-services.mywire.org`;
}

const API_BASE = getApiBase();
let allCourses = [];

async function fetchCourses() {
    try {
        const response = await fetch(`${API_BASE}/api/courses`);
        if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
        allCourses = await response.json();
        return allCourses;
    } catch (e) {
        console.warn("Failed to fetch courses", e);
        return [];
    }
}

async function updateCourseStatus(courseId, newStatus) {
    try {
        const course = allCourses.find(c => c.id == courseId);
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
            <div class="hp-kanban-card-actions">
                <button onclick="window.hpShowCourseModal(${course.id})" title="Edit">✏️</button>
                <button onclick="window.hpDeleteCourse(${course.id})" title="Delete">🗑️</button>
            </div>
            <div class="hp-kanban-card-title">${course.title}</div>
            <div class="hp-kanban-card-desc">${course.description || ''}</div>
            <div class="hp-kanban-card-links">
                ${course.last_link ? `<a href="${course.last_link}" target="_blank" class="milestone-link">🚩 Milestone ↗</a>` : ''}
                <a href="${course.main_link}" target="_blank" class="hub-link">Hub ↗</a>
            </div>
        </div>
    `;
}

async function renderKanban() {
    // Look for the main services grid - this is our insertion point
    const servicesGrid = document.getElementById('services');
    if (!servicesGrid) return;

    // Check if we already created our section
    let section = document.getElementById('hp-learning-hub-section');
    
    if (!section) {
        section = document.createElement('section');
        section.id = 'hp-learning-hub-section';
        section.className = 'hp-kanban-section';
        // Insert after services grid
        servicesGrid.after(section);
        
        section.innerHTML = `
            <div class="hp-section-header">
                <h2>Learning Hub</h2>
                <button class="hp-add-btn" onclick="window.hpShowCourseModal()">+ Add Course</button>
            </div>
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
        injectModal();
    }

    await refreshBoardContent(section);
}

async function refreshBoardContent(section) {
    const courses = await fetchCourses();
    const board = section.querySelector('.hp-kanban-board');
    if (!board) return;

    board.querySelectorAll('.hp-kanban-list').forEach(l => l.innerHTML = '');
    
    courses.forEach(course => {
        const list = board.querySelector(`.hp-kanban-col[data-status="${course.status}"] .hp-kanban-list`);
        if (list) list.innerHTML += createKanbanCard(course);
    });

    // Re-bind Drag & Drop
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
            const draggingCard = document.querySelector(`.hp-kanban-card[data-id="${id}"]`);
            if (draggingCard) col.querySelector('.hp-kanban-list').appendChild(draggingCard);
            await updateCourseStatus(id, status);
        });
    });
}

// Modal Logic
window.hpShowCourseModal = function(id = null) {
    const modal = document.getElementById('hp-course-modal');
    if (!modal) return;
    const form = document.getElementById('hp-course-form');
    modal.style.display = 'flex';
    if (id) {
        const course = allCourses.find(c => c.id == id);
        if (!course) return;
        document.getElementById('hp-modal-title').innerText = 'Edit Course';
        document.getElementById('hp-course-id').value = course.id;
        document.getElementById('hp-title').value = course.title;
        document.getElementById('hp-description').value = course.description || '';
        document.getElementById('hp-main_link').value = course.main_link;
        document.getElementById('hp-last_link').value = course.last_link || '';
        document.getElementById('hp-status').value = course.status;
    } else {
        document.getElementById('hp-modal-title').innerText = 'Add New Course';
        form.reset();
        document.getElementById('hp-course-id').value = '';
    }
};

window.hpCloseModal = () => {
    const modal = document.getElementById('hp-course-modal');
    if (modal) modal.style.display = 'none';
};

window.hpDeleteCourse = async (id) => {
    if (confirm('Delete this course?')) {
        await fetch(`${API_BASE}/api/courses/${id}`, { method: 'DELETE' });
        const section = document.getElementById('hp-learning-hub-section');
        if (section) refreshBoardContent(section);
    }
};

function injectModal() {
    if (document.getElementById('hp-course-modal')) return;
    const modalHtml = `
        <div id="hp-course-modal" class="hp-modal">
            <div class="hp-modal-content">
                <h2 id="hp-modal-title">Add Course</h2>
                <form id="hp-course-form">
                    <input type="hidden" id="hp-course-id">
                    <div class="hp-form-group"><label>Title</label><input type="text" id="hp-title" required></div>
                    <div class="hp-form-group"><label>Description</label><textarea id="hp-description"></textarea></div>
                    <div class="hp-form-group"><label>Main Link</label><input type="url" id="hp-main_link" required></div>
                    <div class="hp-form-group"><label>Milestone Link</label><input type="url" id="hp-last_link"></div>
                    <div class="hp-form-group"><label>Status</label>
                        <select id="hp-status">
                            <option value="WIP">WIP</option>
                            <option value="Planning">Planning</option>
                            <option value="Archive">Archive</option>
                        </select>
                    </div>
                    <div class="hp-modal-actions">
                        <button type="button" onclick="hpCloseModal()">Cancel</button>
                        <button type="submit">Save</button>
                    </div>
                </form>
            </div>
        </div>
    `;
    document.body.insertAdjacentHTML('beforeend', modalHtml);

    document.getElementById('hp-course-form').onsubmit = async (e) => {
        e.preventDefault();
        const id = document.getElementById('hp-course-id').value;
        const data = {
            title: document.getElementById('hp-title').value,
            description: document.getElementById('hp-description').value,
            main_link: document.getElementById('hp-main_link').value,
            last_link: document.getElementById('hp-last_link').value,
            status: document.getElementById('hp-status').value
        };
        const method = id ? 'PUT' : 'POST';
        const url = id ? `${API_BASE}/api/courses/${id}` : `${API_BASE}/api/courses`;
        await fetch(url, {
            method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data)
        });
        window.hpCloseModal();
        const section = document.getElementById('hp-learning-hub-section');
        if (section) refreshBoardContent(section);
    };
}

// Observer
let debounceTimer;
const observer = new MutationObserver(() => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
        const servicesGrid = document.getElementById('services');
        if (servicesGrid && !document.getElementById('hp-learning-hub-section')) {
            renderKanban();
        }
    }, 500);
});

observer.observe(document.body, { childList: true, subtree: true });
renderKanban();
