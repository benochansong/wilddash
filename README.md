# WILD DASH 50

인터넷 연결 없이 Windows PC에 설치해 즐기는 동물 서바이벌 레이싱 게임입니다.

## 개발 실행

Node.js 22.13 이상이 필요합니다.

```powershell
npm install
npm run desktop:dev
```

## 확인 및 설치 프로그램 만들기

```powershell
npm test
npm run dist:win
```

완성된 Windows 설치 프로그램은 `release/WILD-DASH-50-Setup-1.0.0.exe`에 생성됩니다. 설치 후 시작 메뉴나 바탕 화면의 **WILD DASH 50** 바로가기로 실행할 수 있습니다.

게임 진행 기록, 설정, 튜토리얼 완료 여부는 설치된 PC에만 저장됩니다. 웹 서버, Cloudflare 계정, 로그인, 인터넷 연결은 필요하지 않습니다.
