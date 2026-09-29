import logging
from contextlib import asynccontextmanager

import httpx
from fastapi import Depends, FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse

from config import settings
from models.schemas import AnswerResponse, QuestionRequest
from providers.base import AIProvider, AIProviderError, AIProviderTimeout
from providers.groq import GroqProvider
from services import ai_engine

logging.basicConfig(level=logging.INFO, format="[%(levelname)s] %(message)s")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Created once at startup, shared by all requests (warm connections).
    client = httpx.AsyncClient(timeout=settings.ai_timeout_seconds)
    app.state.provider = GroqProvider(settings.groq_api_key, settings.groq_model, client)
    yield
    await client.aclose()


app = FastAPI(title="KOAI Backend", lifespan=lifespan)


def get_provider(request: Request) -> AIProvider:
    return request.app.state.provider


@app.exception_handler(AIProviderTimeout)
async def timeout_handler(request: Request, exc: AIProviderTimeout):
    return JSONResponse(status_code=504, content={"error": "AI provider timeout"})


@app.exception_handler(AIProviderError)
async def provider_error_handler(request: Request, exc: AIProviderError):
    logging.getLogger("koai").error("Provider error: %s", exc)
    return JSONResponse(status_code=502, content={"error": "AI provider error"})


@app.get("/")
def home():
    return {"message": "KOAI Backend is running!"}


TEST_QUIZ_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>KOAI Test Quiz</title>
<style>
  body { font-family: system-ui, sans-serif; margin: 0; padding: 24px;
         background: #f0f2f5; color: #10131a; }
  .card { max-width: 640px; margin: 0 auto; background: #fff; border-radius: 16px;
          padding: 28px; box-shadow: 0 2px 12px rgba(0,0,0,.08); }
  h1 { font-size: 28px; line-height: 1.3; margin: 0 0 24px; }
  .opt { font-size: 24px; padding: 16px 20px; margin: 12px 0; border-radius: 12px;
         color: #fff; font-weight: 700; }
  .a { background: #e21b3c; } .b { background: #1368ce; }
  .c { background: #d89e00; } .d { background: #26890c; }
  button { font-size: 18px; padding: 14px 28px; margin-top: 20px; border: none;
           border-radius: 10px; background: #4630c0; color: #fff; font-weight: 700; }
  .hint { text-align: center; color: #667; margin-top: 16px; font-size: 14px; }
</style>
</head>
<body>
  <div class="card">
    <h1 id="q">Loading…</h1>
    <div class="opt a" id="oa"></div>
    <div class="opt b" id="ob"></div>
    <div class="opt c" id="oc"></div>
    <div class="opt d" id="od"></div>
    <div style="text-align:center"><button onclick="next()">Next question</button></div>
    <p class="hint">Local KOAI test page &mdash; not affiliated with any quiz platform.</p>
  </div>
<script>
  const quiz = [
    ["Which protocol is connection-oriented?", ["UDP","IP","TCP","ICMP"]],
    ["What is the output range of the sigmoid function?",
      ["-1 to 1","0 to 1","0 to infinity","-infinity to infinity"]],
    ["Which SQL command removes rows from a table?",
      ["DROP","DELETE","REMOVE","ERASE"]],
    ["Which data structure uses FIFO order?",
      ["Stack","Queue","Tree","Graph"]],
    ["What is the time complexity of binary search?",
      ["O(n)","O(log n)","O(n log n)","O(1)"]],
    ["Which layer of the OSI model does a router operate at?",
      ["Physical","Data Link","Network","Transport"]]
  ];
  let i = -1;
  function show(n) {
    const [q, opts] = quiz[n];
    document.getElementById('q').textContent = q;
    const ids = ['oa','ob','oc','od'];
    const letters = ['A','B','C','D'];
    for (let k = 0; k < 4; k++)
      document.getElementById(ids[k]).textContent = letters[k] + '. ' + opts[k];
  }
  function next() { i = (i + 1) % quiz.length; show(i); }
  next();
</script>
</body>
</html>
"""


@app.get("/test-quiz", response_class=HTMLResponse)
def test_quiz():
    """A local quiz page for exercising the live capture pipeline in a browser."""
    return TEST_QUIZ_HTML


@app.post("/answer", response_model=AnswerResponse)
async def answer(data: QuestionRequest, provider: AIProvider = Depends(get_provider)):
    return await ai_engine.answer_question(data, provider)