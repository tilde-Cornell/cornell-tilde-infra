from cornell_tilde import commander # type: ignore
from cornell_tilde import verify_username # type: ignore
from cornell_tilde import set_user_bio # type: ignore
from cornell_tilde import get_current_username # type: ignore

def change_bio(l):
    set_user_bio(get_current_username(), l[0])

def hello(l):  
    print("Hello, world!")

main = commander(cmd_list = {
        "hello": (0, hello),
        "change_bio": (1, change_bio),
    }
)
set_user_bio("minh", "hello world")
main()


