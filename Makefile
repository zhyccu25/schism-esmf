# This Makefile is part of the SCHISM-ESMF interface
#
# @copyright (C) 2018, 2019 Helmholtz-Zentrum Geesthacht
# @author Carsten Lemmen carsten.lemmen@hzg.de
# @author Richard Hofmeister richard.hofmeister@hzg.de
#
# @license under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# 		http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# include your ESMF Makefile (esmf.mk), and obtain compiler settings
# from this file
ifndef ESMFMKFILE
$(error ESMFMKFILE has to be set in environment)
endif
include $(ESMFMKFILE)

F90=$(ESMF_F90COMPILER)
LIBS=$(ESMF_F90ESMFLINKLIBS)
CPPFLAGS=$(ESMF_F90COMPILEOPTS)
F90FLAGS=$(ESMF_F90COMPILEPATHS)
LDFLAGS+=$(ESMF_F90LINKOPTS) $(ESMF_F90LINKPATHS)

# add SCHISM libraries
ifndef SCHISM_BUILD_DIR
$(error SCHISM_BUILD_DIR has to be set in environment)
endif
ifneq ($(wildcard $(SCHISM_BUILD_DIR)/libmetis.a),)
$(error SCHISM has to be compiled before ESMF-SCHISM)
endif

LIBS+= -lschism_esmf
F90FLAGS+= -I$(SCHISM_BUILD_DIR)/include
LDFLAGS+= -L$(SCHISM_BUILD_DIR)/lib -L.

EXPAND_TARGETS= expand_schismlibs

ifneq ($(wildcard $(SCHISM_BUILD_DIR)/lib/libfabm.a),)
  $(info Include fabm libraries from $(SCHISM_BUILD_DIR)/lib/libfabm*.a)
  EXPAND_TARGETS+= expand_fabmlibs
  F90FLAGS += -DUSE_FABM
#else
#  $(info Info: no fabm libraries in $(SCHISM_BUILD_DIR)/lib)
endif

all: schism_esmf_lib schism_esmf_test

schism_esmf_test: schism_esmf_test.o schism_esmf_component.o
	$(F90) $(CPPFLAGS) $^ -o $@ $(LDFLAGS) $(LIBS)

concurrent_esmf_test: schism_esmf_component.o dummy_grid_component.o concurrent_esmf_test.o
	$(F90) $(CPPFLAGS) $^ -o $@ $(LDFLAGS) $(LIBS)

schism_esmf_lib: schism_esmf_component.o $(EXPAND_TARGETS)
	$(AR) crus libschism_esmf.a schism_esmf_component.o objs/*/*.o

expand_schismlibs:
	$(shell mkdir -p objs/a; cd objs/a;$(AR) x $(SCHISM_BUILD_DIR)/lib/libparmetis.a)
	$(shell mkdir -p objs/b; cd objs/b;$(AR) x $(SCHISM_BUILD_DIR)/lib/libmetis.a)
	$(shell mkdir -p objs/c; cd objs/c;$(AR) x $(SCHISM_BUILD_DIR)/lib/libcore.a ; $(AR) x  $(SCHISM_BUILD_DIR)/lib/libhydro.a )

expand_fabmlibs:
	$(shell mkdir -p objs/sf; cd objs/sf; for L in $(SCHISM_BUILD_DIR)/lib/lib*fabm_schism.a ; do $(AR) x $$L; done)
	@# $(shell cd objs/sf; nm fabm_schism.F90.o|grep 'fabm_mp\|fabm_types_mp' | awk '{printf $$2 " "; gsub("fabm_mp","s_fabm_mp",$$2); gsub("fabm_types_mp","s_fabm_types_mp",$$2); print $$2}'>replace.tsv; objcopy --redefine-syms=replace.tsv fabm_schism.F90.o)
	$(shell mkdir -p objs/f; cd objs/f; $(AR) x $(SCHISM_BUILD_DIR)/lib/libfabm.a )
	@# $(shell cd objs/f; for O in *.o ; do rm -f replace.tsv; nm -f posix $$O |grep 'fabm_mp\|fabm_types_mp' | awk '{printf $$1 " "; gsub("fabm_mp","s_fabm_mp",$$1); gsub("fabm_types_mp","s_fabm_types_mp",$$1); print $$1}'>replace.tsv; printf "fabm._ s_fabm._\nfabm_types._ s_fabm_types._\n">> replace.tsv; objcopy --redefine-syms=replace.tsv $$O; done)

schism_esmf_component.o: schism_driver_interfaces.mod

%.o: %.F90
	$(F90) $(CPPFLAGS) $(F90FLAGS) -c $<

%.mod: %.F90
	$(F90) $(CPPFLAGS) $(F90FLAGS) -c $<

clean:
	$(RM) *.o *.mod

distclean: clean
	$(RM) -rf objs
	$(RM) schism_esmf_test concurrent_esmf_test libschism_esmf.a