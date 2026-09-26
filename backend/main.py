from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI()


class QuestionRequest(BaseModel):
    question: str
    options: list[str]


@app.get("/")
def home():
    return {"message": "KOAI Backend is running!"}


@app.post("/answer")
def answer_question(data: QuestionRequest):
    return {
        "answer": "B",
        "confidence": 1.0
    }