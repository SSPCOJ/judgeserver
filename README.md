# SSPC Judgeserver

SSPC의 채점 서버입니다.

## 외부 라이브러리

SSPCOJ는 testlib.h와 같은 라이브러리를 간접적으로 사용할 수 있도록 지원합니다.

[deploy](https://github.com/SSPCOJ/deploy)의 docker-compose.yml에서 /spjinclude가 마운트 되어있음을 확인할 수 있습니다. judger는 C++ spj를 컴파일 할 때 /spjinclude에 있는 파일들을 include하므로 testlib.h와 같은 헤더들을 해당 위치에 놓으면 됩니다.
