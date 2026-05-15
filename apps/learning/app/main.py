from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
import uvicorn
import os
import psutil
import docker

from . import models, database

# Create tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Learning Hub API")

# Initialize Docker client
try:
    docker_client = docker.from_env()
except Exception:
    docker_client = None

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Dependency
def get_db():
    db = database.SessionLocal()
    try:
        yield db
    finally:
        db.close()

class CourseBase(BaseModel):
    title: str
    description: Optional[str] = None
    main_link: str
    last_link: Optional[str] = None
    status: str = "Planning"

class CourseCreate(CourseBase):
    pass

class Course(CourseBase):
    id: int
    class Config:
        from_attributes = True

@app.get("/api/system-stats")
def get_system_stats():
    cpu = psutil.cpu_percent(interval=None) # Use None for non-blocking if called frequently
    ram = psutil.virtual_memory()
    # Monitor /home partition
    disk_path = '/home' if os.path.exists('/home') else '/'
    disk = psutil.disk_usage(disk_path)
    return {
        "cpu": cpu,
        "ram_total": round(ram.total / (1024**3), 2),
        "ram_used": round(ram.used / (1024**3), 2),
        "ram_percent": ram.percent,
        "disk_total": round(disk.total / (1024**3), 2),
        "disk_used": round(disk.used / (1024**3), 2),
        "disk_percent": disk.percent
    }

@app.get("/api/services")
def get_services():
    services_config = {
        "infrastructure": [
            {"name": "Traefik", "container": "traefik", "href": "https://traefik.arch-services.mywire.org"},
            {"name": "Authelia", "container": "authelia", "href": "https://auth.arch-services.mywire.org"},
            {"name": "Portainer", "container": "portainer", "href": "https://portainer.arch-services.mywire.org"},
            {"name": "Dozzle", "container": "dozzle", "href": "https://logs.arch-services.mywire.org"},
        ],
        "applications": [
            {"name": "Gitea", "container": "gitea", "href": "https://gitea.arch-services.mywire.org"},
            {"name": "Ollama", "container": "ollama-ollama-1", "href": "https://ollama.arch-services.mywire.org"},
            {"name": "Excalidraw", "container": "excalidraw-excalidraw-1", "href": "https://excalidraw.arch-services.mywire.org"},
            {"name": "Mermaid", "container": "mermaid-live-editor", "href": "https://mermaid.arch-services.mywire.org"},
        ]
    }
    
    results = {"infrastructure": [], "applications": []}
    
    if not docker_client:
        return services_config

    for category in services_config:
        for s in services_config[category]:
            try:
                container = docker_client.containers.get(s["container"])
                status = container.status
            except Exception:
                status = "unknown"
            results[category].append({**s, "status": status})
            
    return results

@app.get("/api/bookmarks")
def get_bookmarks():
    return {
        "Developer": [{"name": "Github", "href": "https://github.com/"}],
        "Social": [{"name": "Reddit", "href": "https://reddit.com/"}],
        "Entertainment": [{"name": "YouTube", "href": "https://youtube.com/"}]
    }

@app.get("/api/courses", response_model=List[Course])
def read_courses(db: Session = Depends(get_db)):
    return db.query(models.Course).all()

@app.post("/api/courses", response_model=Course)
def create_course(course: CourseCreate, db: Session = Depends(get_db)):
    db_course = models.Course(**course.dict())
    db.add(db_course)
    db.commit()
    db.refresh(db_course)
    return db_course

@app.put("/api/courses/{course_id}", response_model=Course)
def update_course(course_id: int, course: CourseCreate, db: Session = Depends(get_db)):
    db_course = db.query(models.Course).filter(models.Course.id == course_id).first()
    if not db_course:
        raise HTTPException(status_code=404, detail="Course not found")
    
    for key, value in course.dict().items():
        setattr(db_course, key, value)
    
    db.commit()
    db.refresh(db_course)
    return db_course

@app.delete("/api/courses/{course_id}")
def delete_course(course_id: int, db: Session = Depends(get_db)):
    db_course = db.query(models.Course).filter(models.Course.id == course_id).first()
    if not db_course:
        raise HTTPException(status_code=404, detail="Course not found")
    db.delete(db_course)
    db.commit()
    return {"message": "Course deleted"}

# Seed initial data if empty
@app.on_event("startup")
def startup_event():
    db = database.SessionLocal()
    if db.query(models.Course).count() == 0:
        initial_courses = [
            models.Course(
                title="Desarrollo Backend con Python",
                description="Platzi Learning Path",
                main_link="https://platzi.com/mis-rutas/16609931/",
                status="WIP"
            ),
            models.Course(
                title="Amazon Junior Software Developer",
                description="Coursera Professional Certificate",
                main_link="https://www.coursera.org/professional-certificates/amazon-junior-software-developer",
                status="WIP"
            ),
            models.Course(
                title="Software Design and Architecture",
                description="Coursera Specialization",
                main_link="https://www.coursera.org/specializations/software-design-architecture",
                status="WIP"
            )
        ]
        db.add_all(initial_courses)
        db.commit()
    db.close()

# Deprecated standalone UI - Serving only API
@app.get("/")
def read_root():
    return {"message": "Learning Hub API is running. Use the main dashboard to access the Kanban board."}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
