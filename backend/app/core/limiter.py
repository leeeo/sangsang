from slowapi import Limiter
from slowapi.util import get_remote_address

# config_filename에 존재하지 않는 파일을 지정해 slowapi가 .env를 읽지 않도록 우회
# (slowapi가 config_filename=None 이어도 .env가 있으면 starlette.Config로 읽으려 시도하는 버그 회피)
limiter = Limiter(key_func=get_remote_address, config_filename=".env.limiter_dummy")
