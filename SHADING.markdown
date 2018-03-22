# SHAding

Vimpire (and any other tooling for that matter) has to be very careful.
We connect to the user's precious process. So we must take care to
minimise the effects on the other side. Due to clojure's limited
abilities in term of isolation, we can easily mess up eg. a common
dependency which we may share with the user code. But even if we take
special care to isolate ourselves from the other side, we still may bang
our own heads together, eg. when several people connect with (possibly
different versions of) vimpire (or any other tooling for that matter) to
the same precious user process.

As [Christophe Grand outlined](http://clj-me.cgrand.net/2018/03/09/content-defined-dependency-shading/)
we can try to minimise our impact to the outer world and protect
ourselves from the sun by putting on proper SHAdes. However that only
moves the battle ground from the backend process to the client.

The royal House of Vim, although introverted, is not xenophobic. It
welcomes other children of the night, as long as they mind their own
business.

Therefore we must also take care that all families adhere to the House's
rules. Only the high lords of each family may be approached. Other
members are to be strictly left alone. Even the high House itself won't
take any interest in the family members. However in exchange they have
to apply proper sunscreen and wear their shades to protect ourselves and
the precious user process. Remember that high stress taints the
delicious values, does it not? That would be a shame.

Each family has to declare their belongings as well as the names of its
high lord's which will be the public face of the family. Obviously each
high lord may only speak for one family. Any attempt of a family to hand
on to the high lord of another family will be interdicted by the Royal
Guards of the House of Vim.

```vim
call vimpire#venom#Register(vimpire#sunscreen#Apply(
            \ "vimpire-complete",
            \ ["venom/complete"],
            \ ["vimpire.complete"],
            \ ["compliment"],
            \ "venom/complete/actions.clj"))
```

This is an example of such a declaration by the “vimpire-complete” family.
The high lord `vimpire.complete` will be known through out the House of Vim
and other families may call upon him. The `compliment` branch of the
family will live in the House of Vim as well, however it shall be left
alone as if it was not there at all. To ensure this, the family is
assigned a dedicated room and every element is transferred too the new
space.

The family stores its belongings in `venom/complete`. The maids of the
royal House take care to clearly identify the ownership with a SHA256
checksum. They also carefully apply Base64 so that the family's
belongings are protected against the elements during transit.

That all said, it must be stated that the high lord's of each family
have to live up to a high responsibility. They are the public face of
the family and have to translate (if necessary) the language between the
outer world and the family room itself.

## Summary

So please let me summarise the key rules of the royal House of Vim.

We create a SHA256 over all the backend code for a vimpire extension.
From this checksum we derive a leading namespace part, which is
prepended to the extension's namespace hierarchy. This applies to
symbols and keywords as well as tagged literals. We do not assume any
cooperation from any 3rd party dependency. We must make the move as
complete as possible. That means also prepending the id marker to things
the could look like the name string of a resource.

These heuristics may fail. Be prepared for that!

Possible namespaced keyword arguments etc. have to translated by the entry
points if necessary. Also leaking out “hard” content like records may
cause problems and should be avoided. This includes also namespaces you
do not own. If you included a 3rd party dependency keep it to yourself
and do not expose it to the other extensions.

The namespaces named explicitly as exposed will be visible to other
extensions. Eg. the “vimpire-complete” extension uses the
`vimpire.util` namespace from the central “vimpire” shading unit.

By hashing the content with SHA256, we can identify identical code and
share the relevant namespace by different vimpire connections to the
same victim process.

While this all might sound complicated, please keep in mind: This also
protects us from the barbarous demons from .el. Company we'd rather
avoid, do we not?
