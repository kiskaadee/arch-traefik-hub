from sqlalchemy import Column, Integer, String
from .database import Base

class Course(Base):
    __tablename__ = "courses"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String)
    description = Column(String, nullable=True)
    main_link = Column(String)
    last_link = Column(String, nullable=True)
    status = Column(String, default="Planning") # WIP, Planning, Archive
