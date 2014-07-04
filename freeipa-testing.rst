FreeIPA Testing
===============

Web UI
------

Wiki link: http://www.freeipa.org/page/Web_UI_Integration_Tests

Download *selenium-server* from http://docs.seleniumhq.org/download/
and run the Selenium server::

  $ java -jar selenium-server-standalone-2.42.2.jar >/dev/null 2>&1 &

If not already installed, installed nose and Selenium::

  $ sudo yum install -y python-nose python-selenium

Run a virtual X server in which to run the tests::

  $ sudo yum install -y xorg-x11-server-Xvfb
  $ export DISPLAY=:99
  $ Xvfb $DISPLAY -ac -screen 0 1400x1200x8 >/dev/null 2>&1 &

Run the tests::

  $ export MASTER=ipa-2.ipa.local ADMINID=admin ADMINPW=4me2Test
  $ export IPA_IP=$(dig +short $MASTER)
  $ ./make-test --logging-level=INFO ipatests/test_webui/
