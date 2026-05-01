def input_string(): return input().rstrip()
def input_iterable(sep = " "): return input_string().split(sep)

def str_is_int(s):
    try:
        int(s)
        return True
    except ValueError:
        return False

def commander(cmd_list = {}):
    previous_exec = []
    state = cmd_list
    is_running = True
    params = []

    def output(*l):
        print(">>",*l)
    
    def repeat(l):
        output("repeating...", *previous_exec)
        exec(previous_exec[0], *previous_exec[1])
    
    exec_no_record = set() #commands that aren't recorded when executed

    def end(l):
        nonlocal is_running
        output("Terminated")
        is_running = False

    def exec(f, *params):
        output(f, *params)
        nonlocal previous_exec
        if f not in exec_no_record:
            previous_exec = (f, params)
        f(*params)    
    
    def is_terminate(token): return isinstance(token, tuple)

    def is_valid(token): return len(token.strip()) != 0
   
    def reset_state():
        nonlocal state, cmd_list, params
        state = cmd_list
        params = []

    def input_token(token):
        """
        handles the input token, change state and execute commands accordingly
        """
        nonlocal state, params

        def confusion(previous_state, candidates):
            def resolution(l):
                if str_is_int(l[0]):
                    return previous_state[candidates[int(l[0])]]
                raise TypeError
                # return previous_state[l[0]]
            return resolution
        
        #read sequence
        if is_terminate(state):
            #if is in functional parameter state
            if state[0] >=0:
                state = (state[0]-1, state[1])
                params.append(token)
        else:
            #if in function selection state
            if token in state:
                state = state[token]
            else:
                #recommend options
                candidates = []
                
                for i, key in enumerate(state.keys()):
                    if key.startswith(token):
                        candidates.append(key)
                lc = len(candidates)
                if lc == 0:
                    output("no valid command, options:", state.keys())
                elif lc == 1:
                    output("autocompleting option:",candidates[0])
                    state = state[candidates[0]]
                else:
                    for i, v in enumerate(candidates):
                        output(i,v)
                    output("options available, choose with int: ")
                    state = (1, confusion(state, candidates))
                
        
        #function execution sequence
        if is_terminate(state):
            if state[0] == 0:
                exec(state[1],params)
                reset_state()
        
    def main():
        reset_state()
        while is_running:
            for token in input_iterable():
                if is_valid(token):
                    input_token(token)
    
    exec_no_record.add(repeat)
    cmd_list["end"] = (0, end)
    cmd_list["repeat"] = (0, repeat)

    return main