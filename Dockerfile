FROM phunehehe/nix:16.09
COPY ./default.nix ./package.nix /root/foomail/
RUN nix-env --install --attr casperjs haskellPackages.hlint nodePackages.eslint \
 && nix-store --gc \
 && nix-shell --run true /root/foomail # This should not be GCed \
 && nix-store --optimize
