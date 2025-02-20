c = get_config()  #noqa

c.Completer.use_jedi = False

c.AliasManager.user_aliases = [
 ('l', 'lsd --group-dirs=first -lah')
]

# disable jedi completion (still broken in dec24)
c.Completer.use_jedi = False

# newp..
# c.MagicsManager.register_alias("p", "paste")

# silence ipython debugging-related logging
# import logging
# logging.getLogger("parso").setLevel(logging.WARNING)
