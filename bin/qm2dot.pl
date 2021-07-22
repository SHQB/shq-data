#!/usr/bin/perl -w

# input log file 
# output hex file and dot file
our $dbug = 0;
my $seed = setseed('provide non-repudable proof of existance');

my $logf = shift;
my $name = shift || $logf; $name =~ s/\.[^.]+//;
my $commitf = "$name.hex";

local *QM; open QM,'<',$logf;
local *F; open F,'>',$commitf;
my @array = ();

# 1st record is the seed
my $n1 = pack('N',time);
#my $n2 = pack('H*','01551220').khash('SHA256',qq'{"seed":$seed}');
my $n2 = khash('SHA256',qq'{"seed":$seed}');
my $nonce = pack('Q',rand64());
my $blob = unpack'H*',$n1.$n2.$nonce;
printf "blob: %s\n",$blob;
printf F "%s %s %s\n",map { unpack'H*',$_ } ($n1,$n2,$nonce);
push @array, $n1.$n2.$nonce;

while (<QM>) {
  if (m/(\d+):?\s(\w+)/) {
    my ($tic,$mh) = ($1,$2);
       $n1 = pack('N',$tic);
       #$n2 = pack('H*','0170').&decode_base58($mh); # assume Qm only for now !
       $n2 = decode_mhash($mh);
       $nonce = pack'Q',rand64();
    push @array,$n1.$n2.$nonce;
    $blob = unpack'H*',$n1.$n2.$nonce;
    printf "blob: %s\n",$blob;
    printf F "%s %s %s\n",map { unpack'H*',$_ } ($n1,$n2,$nonce);
  }
}
my $mklroot = &computeMerkleRoot(\@array);
   $n1 = pack('N',time);
   #$n2 = pack('H*','01551220').$mklroot;
   $n2 = $mklroot;
   $nonce = pack('Q',rand64());
   $blob = unpack'H*',$n1.$n2.$nonce;
printf "blob: %s\n",$blob;
printf F "%s %s %s\n",map { unpack'H*',$_ } ($n1,$n2,$nonce);

close F;
close QM;
exit $?;

sub decode_mhash {
  my $mh = shift;
  if ($mh =~ m/^Qm/) {
    $hash = substr(&decode_base58($mh),2); # assume Qm
  } elsif ($mh =~ m/^z/) {
    $hash = substr(&decode_base58(substr($mh,1)),4); # assume zb2 / zdj
  } elsif ($mh =~ m/^k/) {
    $hash = substr(&decode_base36(substr($mh,1)),4); # k2
  } elsif ($mh =~ m/^b/) {
    $hash = substr(&decode_base32(substr($mh,1)),4); # assume bafy
  } elsif ($mh =~ m/^f/) {
    $hash = pack'H*',substr($mh,1);
  } else {
    $hash = &decode_base58($mh);
  }
}
# -----------------------------------------------------------------------
sub setseed {
  # ecf7fa3d : 15min
  my $key = shift;
  if ("$key" =~ m/\d+/) {
    $seed = srand($key); # seed is global !
    printf "setseed.seed: %08x\n",$seed;
  } elsif ($key =~ m/[a-z]/i) {
    use Digest::MurmurHash;
    $seed = Digest::MurmurHash::murmur_hash($key);
    srand($seed);
    printf "setseed.seed: 0x%08x\n",$seed;
  } else {
    $seed = srand();
    printf "setseed.srand: 0x%08x\n",$seed;
  }
  return $seed;
}
# -----------------------------------------------------------------------
sub rand64 { # /!\ NOT Cryptographycally safe
   my $i1 = int(rand(0xFFFF_FFFF));
   my $i2 = int(rand(0xFFFF_FFFF));
   my $q = $i1 <<32 | $i2;
   printf "i1: %08x\n",$i1 if $dbug;
   printf "i2: %08x\n",$i2 if $dbug;
   printf "rand64: 0x%s\n",unpack'H*',pack'Q',$q if $dbug;
   return $q;
}
# -----------------------------------------------------------------------
sub slugify {
   return (defined $_[0]) ? substr($_[0],0,5) . '.*' . substr($_[0],-3) : 'undefined';
}
sub mbase16 {
  my $mh = sprintf'f%s',unpack'H*',join'',@_;
  return $mh;
}
# -----------------------------------------------------------------------
sub decode_base58 {
  use Math::BigInt;
  use Encode::Base58::BigInt qw();
  my $s = $_[0];
  #$s =~ tr/IO0l/iooL/; # forbidden chars
  $s =~ tr/A-HJ-NP-Za-km-zIO0l/a-km-zA-HJ-NP-ZiooL/; # btc
  my $bint = Encode::Base58::BigInt::decode_base58($s);
  my $bin = Math::BigInt->new($bint)->as_bytes();
  return $bin;
}
# -----------------------------------------------------------------------
sub decode_base36 {
  use Math::BigInt;
  use Math::Base36 qw();
  #$k36 = uc($_[0])
  #$k36 =~ y,A-Z0-9,0-9A-Z;
  my $n = Math::Base36::decode_base36($_[0]);
  my $bin = Math::BigInt->new($n)->as_bytes();
  return $bin;
}
# -----------------------------------------------------------------------
sub decode_base32 {
  use MIME::Base32 qw();
  my $bin = MIME::Base32::decode($_[0]);
  return $bin;
}
# -----------------------------------------------------------------------
sub khash { # keyed hash
   use Crypt::Digest qw();
   my $alg = shift;
   my $data = join'',@_;
   my $msg = Crypt::Digest->new($alg) or die $!;
      $msg->add($data);
   my $hash = $msg->digest();
   return $hash;
}
# -----------------------------------------------------------------------
sub hdate { # return HTTP date (RFC-1123, RFC-2822)
  my ($time,$delta) = @_;
  my $stamp = $time+($delta||0.0);
  my $tic = int($stamp);
  #my $ms = ($stamp - $tic)*1000;
  my $DoW = [qw( Sun Mon Tue Wed Thu Fri Sat )];
  my $MoY = [qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec )];
  my ($sec,$min,$hour,$mday,$mon,$yy,$wday) = (gmtime($tic))[0..6];
  my ($yr4,$yr2) =($yy+1900,$yy%100);

  # Mon, 01 Jan 2010 00:00:00 GMT
  my $date = sprintf '%3s, %02d %3s %04u %02u:%02u:%02u GMT',
             $DoW->[$wday],$mday,$MoY->[$mon],$yr4, $hour,$min,$sec;
  return $date;
}
# -----------------------------------------------------------------------
sub computeMerkleRoot {
  # These numbers have nothing to do with the technology of the devices;
  # they are the maximums that thermodynamics will allow. And they strongly
  # imply that brute-force attacks against 256-bit keys will be infeasible
  # until computers are built from something other than matter and occupy
  # something other than space. -Bruce Schneier, Applied Cryptography

  my $tic = time;
  if (scalar(@{$_[0]}) < 2) {
    return khash('SHA256',@{$_[0]});
  }
  my @ar = @{$_[0]};
  my $n = scalar(@ar);
  printf ".\@ar[%d]:\n\- %s\n",$n,join"\n- ", map { slugify(mbase16($_)); } @ar if $dbug;
  my $m = int(($n+1)/2);
  my $r = 0;
  my $rmax = (log(2*$n-1)/log(2));
  local *DOT; open DOT,'>',"$name.dot";
  print DOT "digraph mkl {\n";
  print DOT qq' graph [pad="0.1", nodesep="0.1", ranksep="1", fontsize=30];\n';
  print DOT qq' //ratio="auto";\n';
  print DOT qq' //layout="sfdp";\n';
  print DOT qq' overlap="false";\n';

  print DOT qq' splines="true";\n';
  print DOT qq' node[pad=10];\n';
  print DOT qq' //node [ fontsize=28 ];\n';
  print DOT qq' //edge[style=invis];\n';
  print DOT qq' edge [ penwidth=2 ];\n';
  printf DOT qq' label="Date: %s, nodes: %d (tics: %s)\ncourtery: Doctor IT <michelc\@drit.ml>";\n',&hdate($tic),$n,$tic;
  
  
  for my $j (0 .. $n-1) { # 1st layer !
      my $node = slugify(mbase16($ar[$j]));
         printf DOT  qq'"%s" [ shape="box"; color="blue"; label="#%d %s" ]\n',$node,$j,$node;
         #printf DOT  qq'"%s" [ label="%s" ]\n',$node,substr($node,-1);
  }
  my $empty=0;
  while (scalar @ar != 1) {
     my @nar = ();
     for my $j (0 .. $n-1) {
         my $node = slugify(mbase16($ar[$j]));
         printf DOT  qq'"%s" [ label="%d.%d %s" fontsize=7 ]\n',$node,$r,$j,substr(mbase16($ar[$j]),-4) if ($r > 0) 
     }
     for my $i (0 .. $m-1) {
       my $hash;
       my $node0 = slugify(mbase16($ar[2*$i]));
       if (exists $ar[2*$i+1]) {
         my $node1 = slugify(mbase16($ar[2*$i+1]));

         $hash = khash('SHA256',$ar[2*$i],$ar[2*$i+1]); # technicall can be a PoW !
         my $nodeup = slugify(mbase16($hash));
         printf "computeMerkleRoot.sha%s.%s (%s,%s) = %s\n",$r,$i,$node0,$node1,$nodeup if $dbug;
         printf DOT qq'"%s" -> { "%s", "%s" }\n',$nodeup,$node0,$node1;
       } else {
         $hash = khash('SHA256',$ar[2*$i]);
         my $nodeup = slugify(mbase16($hash));
         printf "computeMerkleRoot.sha%s.%s (%s,-) = %s\n",$r,$i,$node0,$nodeup if $dbug;
         printf DOT  qq'"%s" -> { "%s", "[%s]" }\n',$nodeup,$node0,$empty++;
       }
       #printf "khash: %s\n",unpack'H*',$hash if $dbug;
       push @nar, $hash;
     }
     @ar = @nar;
     $n = scalar(@ar);
     $m = int(($n+1)/2);
     $r++;
     printf ".\@ar.%d[%d]:\n\- %s\n",$r,$n,join"\n- ", map { slugify(mbase16($_)); } @ar if $dbug;
    last  if $r > $rmax;
  }
  my $root = slugify(mbase16($ar[0]));
  printf DOT  qq'"%s" [ shape="box"; color="red"; label="%d.%d %s" ]\n',$root,$r,0,$root;
  print DOT "}\n";
  printf "computeMerkleRoot.sha%s.%s %s\n",$r,0,slugify(mbase16($ar[0]));
  return $ar[0];

}
# -----------------------------------------------------------------------

1; # $Source: /my/perl/scripts/qm2mkl.pl $


