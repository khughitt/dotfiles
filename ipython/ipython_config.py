c = get_config()  #noqa

c.AliasManager.user_aliases = [
 ('l', 'lsd --group-dirs=first -lah')
]

# disable jedi completion (broken with pandas object completion, oct23)
c.Completer.use_jedi = False

# newp..
# c.MagicsManager.register_alias("p", "paste")

# silence ipython debugging-related logging
# import logging
# logging.getLogger("parso").setLevel(logging.WARNING)
