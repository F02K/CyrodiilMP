# CyrodiilMP MVP

## Goal

The first CyrodiilMP milestone is a dedicated server that lets one player see another player in Oblivion Remastered with position synced.

This is not full multiplayer yet. It is the smallest useful proof that the project can:

- Connect the game client to an external server.
- Identify each connected player.
- Track each player's world/cell and transform.
- Spawn or update a remote player proxy in the local UE5 scene.
- Despawn that proxy when the player disconnects or leaves relevance range.

## Dedicated Server Responsibilities

- Accept client connections.
- Assign a temporary player ID.
- Track player session state.
- Receive position snapshots from clients.
- Broadcast relevant player snapshots to nearby clients.
- Remove players cleanly on disconnect.

The server should be authoritative for identity, session membership, and which players are visible to each other. For the first prototype, the client can remain temporarily authoritative for its own movement.

## Client Responsibilities

- Connect to the dedicated server.
- Send a regular local player transform snapshot.
- Receive remote player snapshots.
- Create a remote player proxy actor or equivalent runtime representation.
- Smooth/interpolate remote movement between snapshots.
- Remove stale proxies.

## First Network Messages

- `ClientHello` - client version, player name, optional mod version.
- `ServerWelcome` - assigned player ID, server tick rate.
- `PlayerTransform` - player ID, world/cell identifier, position, rotation, velocity, timestamp.
- `PlayerJoined` - player ID and display name.
- `PlayerLeft` - player ID and reason.
- `ServerSnapshot` - batched transform updates for visible players.

## State To Sync First

- Player ID
- Display name
- World or cell identifier
- Position
- Rotation
- Velocity
- Basic movement/animation hint, such as idle, walking, running, jumping, swimming, mounted if detectable

## Out Of Scope For MVP

- Combat
- Damage
- Inventory
- Equipment visuals beyond a placeholder model
- Quests
- Dialogue
- Containers
- NPC AI
- World object changes
- Save-game persistence
- Anti-cheat

## Suggested Tick Rates

- Client sends local transform: 10-20 Hz.
- Server broadcasts snapshots: 10-20 Hz.
- Client renders remote proxy every frame with interpolation.

## Prototype Success Criteria

- Two clients can connect to one dedicated server.
- Client A can see a proxy for Client B.
- Moving Client B updates the proxy position on Client A.
- Disconnecting Client B removes the proxy from Client A.
- Basic movement remains stable for at least 10 minutes in a controlled test location.
