# Set a custom session root path. Default is `$HOME`.
# Must be called before `initialize_session`.
#session_root "~/Projects/session1"

# Create session with specified name if it does not already exist. If no
# argument is given, session name will be based on layout file name.
if initialize_session "session1"; then

  # Create a new window inline within session layout definition.
  new_window "session1"
  split_h 50
  split_v 50
  run_cmd "mc"
  select_pane 1
  run_cmd "htop"
  #select_pane 2

  new_window "serial1"
  split_h 50
  split_h 50
  #split_v 50
  select_pane 0
  split_h 50
  #split_v 50
  select_pane 0
  #run_cmd "clear"
  run_cmd ".tmuxifier/layouts/tmux.tty2"
  #run_cmd "picocom -b 115200 /dev/ttyS2"
  select_pane 1
  run_cmd ".tmuxifier/layouts/tmux.tty3"
  #run_cmd "picocom /dev/ttyS3"
  select_pane 2
  run_cmd ".tmuxifier/layouts/tmux.tty4"
  #run_cmd "picocom /dev/ttyS4"
  select_pane 3
  #run_cmd "picocom /dev/ttyS5"
  run_cmd ".tmuxifier/layouts/tmux.tty5"
  #select_pane 0

  # Load a defined window layout.
  #load_window "example"

  # Select the default active window on session creation.
  select_window 0
  select_pane 0
  run_cmd "neofetch"
  run_cmd ".tmuxifier/layouts/tmux.help"
  select_pane 2
fi

# Finalize session creation and switch/attach to it.
finalize_and_go_to_session
