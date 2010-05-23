| Copyright 2010 `John Wiseman`_

fireflysync
==========

This is a Processing sketch that simulates a simple way for fireflies to sycnhronize their flashes.


.. image:: http://github.com/wiseman/fireflysync/raw/master/images/fireflies-sync.jpg

.. image:: http://github.com/wiseman/4mapper/raw/master/screenshots/4mapper-2.jpg


How it doesn't work
--------------------

The site doesn't work at all in Internet Explorer.
				   
4mapper does not do a good job of translating errors into readable
messages.  Usually this comes up when a Foursquare API call times out,
and the Google App Engine throws a DownloadError.

There is a bug in session logic that can result in a History record
with a null history.  The app doesn't deal with null histories well.

There's a Javascript error that pops up sometimes, too; If you see
something about a "null bbox", something has gone wrong inside the
Cartographer library.

It seems that Foursquare sometimes invalidates user photo URLs; Since
4mapper only updates that info when a user authorizes it, we can end
up trying to show bad photo URLs on the ``/users`` page.

This is the closest thing to a webapp I've written in years, and it is
my first Google AppEngine application.  It's probably wrong.



.. _John Wiseman: http://twitter.com/lemonodor
