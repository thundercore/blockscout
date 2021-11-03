#!/bin/sh

mix do ecto.create, ecto.migrate; mix phx.server