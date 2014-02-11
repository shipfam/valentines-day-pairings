/**

i'm sorry ahead of time for how ugly this code is. i just needed
it to work once. to run it again, you'll need the input file of
addresses from Emily.

the general idea is this:

if you're not going to send out a lot of cards, you're (hopefully)
putting a lot of thought into the ones you do send, so you should
be getting cards from people similarly sending out very thoughtful
cards.

on the flip side, if you're shotgunning your cards out, you should
get cards from other people similarly shotgunning cards out.

so sort all of the rows by the number of cards people want to send out
and then (for example) if a person wants to send out N cards, give them
the N closest people. but throw in some magic by adding a random number
on a normal distribution with a std dev of 10 (because valentine's day
means STDs duh).

then create a CSV file for every person, and send that to them. the emailing
could be automated too, but I didn't bother.

**/


libname desktop 'C:\Users\phbusb\Desktop\vday';

data base;
  length id 8.;
  set desktop.vals2(keep=id cards);
  if(cards > 151) then cards=151;
  num_recv=cards;
  num_send=cards;

  if(_n_=1) then do;
	call streaminit(123456);
  end;

  rand = rand('UNIFORM');
run;

proc sql;
  create table square as
  select a.id as send_id, a.num_send as send_num, a.rand
    from base a;
quit;

data square;
  set square;
  *send_num = round(send_num+(rand*10));
  drop rand;
run;

proc sort data=square;
  by send_num;
run;
data square;
  set square;
  center = _n_;
  stddev = send_num;
run;

proc sql;
  create table sendlist as
  select a.send_id, b.send_id as recv_id, a.center as send_center, b.center as recv_center, a.center-b.center as difference, a.stddev
    from square a, square b
	order by a.center, b.center;
quit;
data sendlist;
  set sendlist;
  rand = rand('NORMAL')*10 + abs(difference);
  by send_center recv_center;
run;
proc sort data=sendlist;
  by send_id rand;
run;
data sendlist;
  retain count 0;
  set sendlist;
  by send_id rand;
  if(first.send_id) then count=0;
  count+1;
  if(count <= stddev + 1 and send_id ^= recv_id) then output;
run;

proc sql;
  create table final as
  select
    a.id, a.email, a.cards as sender_max_send, b.name as recv, b.email as recv_email, b.cards as recv_has_sent, b.allergies, b.status, b.date
	from sendlist x
	  inner join desktop.vals2 a on (x.send_id = a.id)
	  inner join desktop.vals2 b on (x.recv_id = b.id)
	order by X.send_center;
quit;

proc sql;
  create table emails as
  select distinct a.id, compress(email,'','kad') as email
    from desktop.vals2 a;
quit;

%macro genfile(id,email);
proc export data=final(where=(id=&id))
  outfile="c:\users\phbusb\desktop\vday\&id._&email..csv"
  dbms=csv replace;
run;
%mend;

data _null_;
  set emails;
  call execute('%genfile('||id||','||email||')');
run;


data desktop.sendlist;
  set sendlist;
run;
