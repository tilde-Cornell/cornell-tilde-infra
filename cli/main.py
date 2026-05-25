from commander import commander_prompt_toolkit_loop
# from cornell_tilde import verify_username
from cornell_tilde import set_user_bio
from cornell_tilde import get_current_username

def change_bio(l):
    print("BIO")
    set_user_bio(get_current_username(), l[0])

def hello(l):  
    print("Hello, world!")

commander_prompt_toolkit_loop(
    dict_command = {
        "hello": (0, hello),
        "change_bio": (1, change_bio),
    }
)


