#!/bin/sh -x

createdb $1 -O $2

psql $1 $2 < sql/schema.sql
