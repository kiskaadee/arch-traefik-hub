from fastapi import FastAPI, Depends, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session
from typing import List, Optional
from pydantic import BaseModel
import uvicorn
import os

from . import models, database

# Create tables
models.Base.metadata.create_all(bind=database.engine)

app = FastAPI(title="Learning Hub API")

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

# Serves CSS/JS and index
app.mount("/", StaticFiles(directory="app/static", html=True), name="static")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
