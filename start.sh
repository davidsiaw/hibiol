if [ $# -eq 0 ]
  then
    foreman start
elif [ "$1" = "build" ]
  then
	bundle exec weaver build
	cp -a build/. release
else
	exec $*
fi
