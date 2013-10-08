visual_resume
=============

You'll need at least: 

- Linkedin API's keys https://www.linkedin.com/secure/developer
- MySQL database
- phantomjs

What you'll eventually need:

- A SlideShare API's key http://www.slideshare.net/developers/applyforapi

To run the application, just run `unicorn` at the root of the directory.

Story
-----

[Simla Ceyhan](www.linkedin.com/in/simla), [Yifu Diao](http://www.linkedin.com/in/yifudiao) and [I](http://www.linkedin.com/in/sylvainkalache) created this project for the [SlideShare](http://www.slideshare.net/) hackathon October 2013. This project gave us the second place at the hackathon.

We thought that LinkedIn give us the possibility to give very interesting insights about profesionnal that we could not get before it. Indeed, we know have a lot of metadata that allow us to figure out the profile of a person pretty quickly.

Companies are often asking for a pdf version of your resume, the candidate can come up with an original, easy to read version of his profile.


Install on Ubuntu (tested with Vagrant)
---------------------------------------

    apt-get install ruby-dev libmysqlclient-dev mysql-server phantomjs
    gem install bundler
    gem install nokogiri -v '1.6.0'
    bundle install
    nano credentials.yml # fill with valid data
    echo 'CREATE DATABASE visualresume' | mysql -uroot -p
    rake db:reset
    unicorn
