How to generate virtual keyboard events
---------------------------------------

- ``sudo evemu-event --sync --type EV_KEY \
      --code KEY_Q --value 1 /dev/input/eventXXX``

- replace it with your keyboard's event node
    (run evemu-record for the list) and that'll put the key down

- value 0 releases it

- alternate it with KEY_A in a shellscript and off you go
