"""MP별 ANT 제출 ZIP을 만든다.

git에 커밋된 파일만 담으므로 build/, .dart_tool/ 같은 생성 폴더와 .env는 들어가지 않는다.

    python3 tool/make_submission.py mp3            # HEAD 기준, submit-mp3.zip
    python3 tool/make_submission.py mp1 --ref mp1-resubmit -o out.zip

ZIP 구성
- app/, README.md, prompts_log.md (공통)
- screenshots/: 저장소의 screenshots/<mp>/ 사진을 폴더 없이 넣는다
- .env.example: mp3만, app/.env.example 사본을 최상위에 넣는다
- firestore.rules, firebase.json: mp3만, README '백엔드 설정 절차'가 쓰는 파일이라 최상위에 넣는다
- README.md: '확인 방법' 절에서 그 MP 블록만 남기고 저장소 안내 문단을 뺀다

검사: 스크린샷 12장 이하·01_ 번호·2MB 이하, README가 적은 파일 이름이 실제로 있는지,
README 필수 절과 확인 방법의 기준 소제목, 금지 파일(.env, Firebase 구성 파일, 빌드 폴더)과
키 문자열이 없는지.
"""

import argparse
import re
import subprocess
import sys
import zipfile
from pathlib import Path

MPS = ("mp1", "mp2", "mp3", "mp4")
MAX_SHOTS = 12
MAX_SHOT_BYTES = 2 * 1024 * 1024
FORBIDDEN_DIRS = ("build/", ".dart_tool/", ".gradle/", "Pods/", "DerivedData/", "node_modules/")
FORBIDDEN_NAMES = (".env", "google-services.json", "GoogleService-Info.plist")
KEY_PATTERN = re.compile(rb"AIza[0-9A-Za-z_\-]{35}")
# ANT가 지정한 Flutter 3.47.5의 커밋. 3.47.4 커밋이 남은 app/.metadata로 제출해 '개발 환경' 보완 판정을 받았다(2026-11-23).
FLUTTER_REVISION = "6a19cca56475dbfba1478ee68d7bd0c2ef891da1"
# ANT 'README 필수 절' 검사가 제목으로 찾는 절. 2026-11-23 결과 화면의 지적을 반영했다.
REQUIRED_HEADINGS = {
    "mp1": ("실행 절차", "확인 방법", "구현 기능", "화면 구성"),
    "mp2": ("실행 절차", "확인 방법", "로컬 저장 방식 비교"),
    "mp3": ("실행 절차", "확인 방법", "BaaS 선택", "충돌 처리 방침", "백엔드 설정 절차"),
    "mp4": ("실행 절차", "확인 방법", "인식 기능", "검토 UI 흐름", "처리 시간"),
}
# ANT 결과 화면 '기능 평가'의 항목 이름(2026-11-24 확인). 확인 방법 절의 ### 소제목으로 그대로 쓴다.
CRITERIA_HEADINGS = {
    "mp1": ("목록·추가·완료", "빈 상태 안내", "상태 반영 구조", "프롬프트 기록"),
    "mp2": ("재시작 후 유지", "저장 방식 선택 이유", "수정·삭제·필터", "프롬프트 기록"),
    "mp3": ("두 기기 동기화", "오프라인 작성 후 반영", "충돌 처리 방침", "키 분리", "프롬프트 기록"),
    "mp4": ("사진에서 항목 저장", "비행기 모드 동작", "원본 사진 비저장", "권한 거부 안내", "프롬프트 기록"),
}
# MP별로 ZIP 최상위에 더 넣는 파일 (ZIP 경로: 저장소 경로).
# mp3의 보안 규칙이 빠지면 README대로 만든 Firestore가 모든 읽기·쓰기를 거부한다.
EXTRA_FILES = {
    "mp3": {
        ".env.example": "app/.env.example",
        "firestore.rules": "firestore.rules",
        "firebase.json": "firebase.json",
    },
}


def git(*args: str) -> bytes:
    return subprocess.run(["git", *args], check=True, capture_output=True).stdout


def tracked_files(ref: str, path: str) -> list[str]:
    out = git("ls-tree", "-r", "-z", "--name-only", ref, "--", path)
    return [p for p in out.decode().split("\0") if p]


def read_file(ref: str, path: str) -> bytes:
    return git("show", f"{ref}:{path}")


def build_readme(text: str, mp: str) -> str:
    """'확인 방법'에서 다른 MP 블록과 저장소 안내를 빼고, 표시 주석을 지운다."""
    def drop(match: re.Match) -> str:
        return match.group(0) if match.group(1) == mp else ""

    text = re.sub(
        r"<!-- submission:(\w[\w-]*) -->\n.*?<!-- /submission:\1 -->\n\n?",
        drop,
        text,
        flags=re.S,
    )
    text = re.sub(rf"<!-- /?submission:{mp} -->\n", "", text)
    if "submission:" in text:
        sys.exit("README에 처리하지 못한 submission 표시가 남았습니다.")
    return text


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("mp", choices=MPS)
    parser.add_argument("--ref", default="HEAD", help="담을 커밋·태그 (기본 HEAD)")
    parser.add_argument("-o", "--output", help="ZIP 경로 (기본 submit-<mp>.zip)")
    args = parser.parse_args()
    mp, ref = args.mp, args.ref
    output = Path(args.output or f"submit-{mp}.zip")

    entries: dict[str, bytes] = {}
    for path in tracked_files(ref, "app"):
        entries[path] = read_file(ref, path)
    entries["prompts_log.md"] = read_file(ref, "prompts_log.md")
    readme = build_readme(read_file(ref, "README.md").decode(), mp)
    entries["README.md"] = readme.encode()
    for name, source in EXTRA_FILES.get(mp, {}).items():
        entries[name] = read_file(ref, source)

    shots = [p for p in tracked_files(ref, f"screenshots/{mp}") if not p.endswith(".gitkeep")]
    shot_names = []
    for path in shots:
        name = Path(path).name
        shot_names.append(name)
        entries[f"screenshots/{name}"] = read_file(ref, path)

    errors = []
    if not 1 <= len(shot_names) <= MAX_SHOTS:
        errors.append(f"스크린샷이 {len(shot_names)}장입니다 (1–{MAX_SHOTS}장).")
    for index, name in enumerate(sorted(shot_names), start=1):
        if not re.fullmatch(rf"{index:02d}_[A-Za-z0-9_\-]+\.(png|jpg|jpeg)", name):
            errors.append(f"스크린샷 이름이 순서 번호·영문 형식이 아닙니다: {name}")
        if len(entries[f"screenshots/{name}"]) > MAX_SHOT_BYTES:
            errors.append(f"2MB를 넘는 스크린샷: {name}")
    for listed in re.findall(r"^- 스크린샷: (.+)$", readme, flags=re.M):
        for name in (n.strip() for n in listed.split(",")):
            if name not in shot_names:
                errors.append(f"README가 적은 스크린샷이 없습니다: {name}")
    for heading in REQUIRED_HEADINGS[mp]:
        if not re.search(rf"^#{{2,3}} {re.escape(heading)}$", readme, flags=re.M):
            errors.append(f"README에 '{heading}' 절(## 또는 ###)이 없습니다.")
    checks = readme.split("\n## 확인 방법\n", 1)[-1].split("\n## ", 1)[0]
    for heading in CRITERIA_HEADINGS[mp]:
        if not re.search(rf"^### {re.escape(heading)}$", checks, flags=re.M):
            errors.append(f"확인 방법에 기준 소제목 '### {heading}'이 없습니다.")
    for block in re.split(r"^### ", checks, flags=re.M)[1:]:
        title = block.splitlines()[0]
        if "\n- 조작: " not in block or "\n- 기대 결과: " not in block:
            errors.append(f"확인 방법 '{title}'에 조작·기대 결과 줄이 없습니다.")
    metadata = entries["app/.metadata"].decode()
    revisions = set(re.findall(r"revision: \"?([0-9a-f]{40})", metadata))
    if revisions != {FLUTTER_REVISION}:
        errors.append(f"app/.metadata의 Flutter 커밋이 3.47.5가 아닙니다: {sorted(revisions)}")
    for path, data in entries.items():
        if any(f"/{d}" in f"/{path}" for d in FORBIDDEN_DIRS):
            errors.append(f"빌드 산출물: {path}")
        if Path(path).name in FORBIDDEN_NAMES:
            errors.append(f"금지 파일: {path}")
        if KEY_PATTERN.search(data):
            errors.append(f"키 문자열이 있습니다: {path}")
    if errors:
        sys.exit("\n".join(errors))

    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(entries):
            zf.writestr(path, entries[path])
    size_mb = output.stat().st_size / 1024 / 1024
    top = sorted({p.split("/")[0] for p in entries})
    print(f"{output}: {len(entries)}개 파일, {size_mb:.1f}MB, 스크린샷 {len(shot_names)}장")
    print("최상위:", ", ".join(top))


if __name__ == "__main__":
    main()
