#include "ruby/ruby.h"
#include "ruby/debug.h"

struct arg_info {
    int argc;
    VALUE *argv;
};

static VALUE
binding_of_caller_i(const rb_debug_inspector_t *dbg_context, void *data)
{
    static const int lev_default = 1;
    static const int lev_plus = 1;
    VALUE level, vn;
    long lev, n;

    struct arg_info *arg = (struct arg_info*)data;
    int argc = arg->argc;
    VALUE *argv = arg->argv;

    VALUE locs = rb_debug_inspector_backtrace_locations(dbg_context);
    long i, locs_len = RARRAY_LEN(locs);
    VALUE r;

    rb_scan_args(argc, argv, "02", &level, &vn);

    if (argc == 2 && NIL_P(vn)) argc--;

    switch (argc) {
      case 0:
	lev = lev_default + lev_plus;
	n = locs_len - lev;
	break;
      case 1:
	{
	    long beg, len;
	    switch (rb_range_beg_len(level, &beg, &len, locs_len - lev_plus, 0)) {
	      case Qfalse:
		lev = NUM2LONG(level);
		if (lev < 0) {
		    rb_raise(rb_eArgError, "negative level (%ld)", lev);
		}
		lev += lev_plus;
		n = locs_len - lev;
		break;
	      case Qnil:
		return Qnil;
	      default:
		lev = beg + lev_plus;
		n = len;
		break;
	    }
	    break;
	}
      case 2:
	lev = NUM2LONG(level);
	n = NUM2LONG(vn);
	if (lev < 0) {
	    rb_raise(rb_eArgError, "negative level (%ld)", lev);
	}
	if (n < 0) {
	    rb_raise(rb_eArgError, "negative size (%ld)", n);
	}
	lev += lev_plus;
	break;
      default:
	lev = n = 0; /* to avoid warning */
	break;
    }

    if (n < 0) {
	return Qnil;
    }
    else if (n == 0) {
	return rb_ary_new();
    }

    r = rb_ary_new();
    for (i=0; i+lev<locs_len && i<n; i++) {
	rb_ary_push(r, rb_debug_inspector_frame_binding_get(dbg_context, i+lev));
    }

    return r;
}

static VALUE
binding_of_caller(int argc, VALUE *argv)
{
    struct arg_info arg = { argc, argv };

    return rb_debug_inspector_open(binding_of_caller_i, &arg);
}

void
Init_binding(void)
{
    rb_define_module_function(rb_cBinding, "of_caller", binding_of_caller, -1);
}
