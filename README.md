# SSPC Judgeserver

SSPC의 채점 서버입니다.

## header-only 라이브러리

SSPCOJ는 C++ 스페셜 저지 코드가 header-only 라이브러리를 사용할 수 있도록 지원합니다.

[deploy](https://github.com/SSPCOJ/deploy)의 docker-compose.yml에서 /spjinclude가 마운트 되어있음을 확인할 수 있습니다. judger는 C++ 스페셜 저지 코드를 컴파일 할 때 /spjinclude에 있는 파일들을 검색 경로에 넣습니다.
