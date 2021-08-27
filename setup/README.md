# Docker-Swarm-Install

## Getting Started
Please log into the machine that requires installation and run the script  
*Note:* A snapshot should always be done prior to installation

## Usage
>Options are:  
`-d` or `--dev` for dev,  
`-l` or `--leader` for leader,  
`-h` or `--help` for help.  

Run the command listed below and modify it accordingly with the following arguments:
* If doing a developmental install (aka not allocating a disk for Docker), append the `--dev` or `-d` options
* If node is a manager and the swarm itself has not been created, append the `--leader` or `-l` options to start a new swarm and produce tokens
  + You can also use this option on a node that is already in a swarm and has a role of "Manager" or "Leader". This will produce tokens that give access for other managers or workers to join the swarm


### Install docker as a Manager
```
curl -sSL https://raw.githubusercontent.com/jaredbrogan/Docker/main/setup/swarm_install.sh | bash -s -- -l
```

### Install docker as a Worker
```
curl -sSL https://raw.githubusercontent.com/jaredbrogan/Docker/main/setup/swarm_install.sh | bash
```

### Install docker in dev mode (no attached hard disk)
```
curl -sSL https://raw.githubusercontent.com/jaredbrogan/Docker/main/setup/swarm_install.sh | bash -s -- -d
```

#### Remember to change the Docker password afterwards. A temporary password will be randomly generated for you when the Docker user is created

----

## Contributors
* [**Jared Brogan**](https://github.com/jaredbrogan)
