let courses = [];

async function fetchCourses() {
    const response = await fetch('/api/courses');
    courses = await response.json();
    renderBoard();
}

function renderBoard() {
    const columns = ['WIP', 'Planning', 'Archive'];
    columns.forEach(status => {
        const list = document.getElementById(`list-${status}`);
        list.innerHTML = '';
        const filtered = courses.filter(c => c.status === status);
        filtered.forEach(course => {
            const card = createCard(course);
            list.appendChild(card);
        });
    });
}

function createCard(course) {
    const card = document.createElement('div');
    card.className = 'course-card';
    card.draggable = true;
    card.id = `course-${course.id}`;
    card.innerHTML = `
        <div class="card-actions">
            <button onclick="editCourse(${course.id})">✏️</button>
            <button onclick="deleteCourse(${course.id})">🗑️</button>
        </div>
        <h3>${course.title}</h3>
        <p>${course.description || ''}</p>
        <div class="card-links">
            <a href="${course.main_link}" target="_blank">Main</a>
            ${course.last_link ? `<a href="${course.last_link}" target="_blank">Milestone</a>` : ''}
        </div>
    `;

    card.addEventListener('dragstart', (e) => {
        e.dataTransfer.setData('text/plain', course.id);
        card.classList.add('dragging');
    });

    card.addEventListener('dragend', () => {
        card.classList.remove('dragging');
    });

    return card;
}

function allowDrop(e) {
    e.preventDefault();
}

async function drop(e) {
    e.preventDefault();
    const courseId = e.dataTransfer.getData('text/plain');
    const newStatus = e.currentTarget.id; // The column ID
    
    const course = courses.find(c => c.id == courseId);
    if (course && course.status !== newStatus) {
        course.status = newStatus;
        await updateCourseOnServer(course);
        renderBoard();
    }
}

async function updateCourseOnServer(course) {
    await fetch(`/api/courses/${course.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(course)
    });
}

async function deleteCourse(id) {
    if (confirm('Are you sure?')) {
        await fetch(`/api/courses/${id}`, { method: 'DELETE' });
        await fetchCourses();
    }
}

// Modal Logic
const modal = document.getElementById('course-modal');
const form = document.getElementById('course-form');

function showModal(id = null) {
    modal.style.display = 'block';
    if (id) {
        const course = courses.find(c => c.id == id);
        document.getElementById('modal-title').innerText = 'Edit Course';
        document.getElementById('course-id').value = course.id;
        document.getElementById('title').value = course.title;
        document.getElementById('description').value = course.description || '';
        document.getElementById('main_link').value = course.main_link;
        document.getElementById('last_link').value = course.last_link || '';
        document.getElementById('status').value = course.status;
    } else {
        document.getElementById('modal-title').innerText = 'Add New Course';
        form.reset();
        document.getElementById('course-id').value = '';
    }
}

function closeModal() {
    modal.style.display = 'none';
}

form.onsubmit = async (e) => {
    e.preventDefault();
    const id = document.getElementById('course-id').value;
    const courseData = {
        title: document.getElementById('title').value,
        description: document.getElementById('description').value,
        main_link: document.getElementById('main_link').value,
        last_link: document.getElementById('last_link').value,
        status: document.getElementById('status').value
    };

    if (id) {
        await fetch(`/api/courses/${id}`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(courseData)
        });
    } else {
        await fetch('/api/courses', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(courseData)
        });
    }
    
    closeModal();
    await fetchCourses();
};

window.onclick = (e) => {
    if (e.target == modal) closeModal();
};

function editCourse(id) {
    showModal(id);
}

// Initial fetch
fetchCourses();
