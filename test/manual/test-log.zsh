#!/usr/bin/env zsh

the_usual=${${(%):-%x}:A:h:h:h}  # the-usual repo root

source $the_usual/log.zsh

log_success "log_success"
log_success_v "log_success_v"
log_success_vv "log_success_vv"
log_info "log_info"
log_info_v "log_info_v"
log_info_vv "log_info_vv"
log_warning "log_warning"
log_warning_v "log_warning_v"
log_warning_vv "log_warning_vv"
log_error "log_error"
log_error_v "log_error_v"
log_error_vv "log_error_vv"

print "Remaining arguments: $*"

log_fatal "log fatal and exit 42" 42
