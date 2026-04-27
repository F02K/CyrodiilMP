# Protocol Notes

The first protocol should stay tiny and debuggable. Prefer boring binary or structured messages over clever compression until the movement prototype works.

## Candidate Packet Shape

```text
packet_type
sequence
server_time_or_client_time
payload
```

## Transform Snapshot

```text
player_id
world_id_or_cell_id
position_x
position_y
position_z
rotation_pitch
rotation_yaw
rotation_roll
velocity_x
velocity_y
velocity_z
movement_state
timestamp
```

## Early Transport Choice

UDP-style networking is probably the right fit for movement sync. Candidate libraries:

- LiteNetLib if the server is C#/.NET.
- ENet if using C/C++ or bindings.
- Steam Networking Sockets if Steam integration becomes a goal.

Use reliable messages for connect/disconnect/player identity, and unreliable or semi-reliable messages for high-frequency transforms.
