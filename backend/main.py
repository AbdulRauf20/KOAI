from fastapi import FastAPI
from pydantic import BaseModel

from answer_engine import find_answer

app = FastAPI()


class QuestionRequest(BaseModel):
    question: str
    options: list[str]


@app.get("/")
def home():
    return {"message": "KOAI Backend is running!"}


@app.post("/answer")
def answer_question(data: QuestionRequest):

    answer, confidence = find_answer(
        data.question,
        data.options
    )

    return {
        "answer": answer,
        "confidence": confidence
    }