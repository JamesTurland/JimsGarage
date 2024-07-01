FROM mcr.microsoft.com/devcontainers/python:1-3.12-bookworm

# enable git bash completion
RUN ln -s /usr/share/bash-completion/completions/git /usr/share/bash-completion/bash_completion

# install sshpass for ansible SSH password auth and vim just in case
RUN apt-get update && apt-get upgrade -y
RUN apt-get install -y sshpass vim
RUN apt-get clean

# install ansible and ansible-lint
RUN python3 -m pip install ansible-core~=2.16.6 ansible-lint~=24.2.3

# create /workspace directory
WORKDIR /workspace
RUN chown -R vscode:vscode /workspace

# run commands as non-root user
USER vscode

# make prompt multiline cause it's too long by default
RUN sed -i -E -e '/PS1="\$/c\    PS1="${userpart} ${lightblue}\\w ${gitbranch}${removecolor}\\n\\$ "' ~/.bashrc

# install collection requirements
COPY collections/requirements.yaml .
RUN ansible-galaxy collection install -r requirements.yaml
