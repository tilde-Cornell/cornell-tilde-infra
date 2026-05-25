import getpass

def get_current_username():
    return getpass.getuser()

def verify_username(username):
    return username == get_current_username()