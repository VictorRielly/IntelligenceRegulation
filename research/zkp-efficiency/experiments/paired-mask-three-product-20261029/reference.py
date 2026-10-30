"""Independent schoolbook Fp2/original-cube oracle, no candidate imports."""
Q=18446744069414584321
def plus(x,y):return ((x[0]+y[0])%Q,(x[1]+y[1])%Q)
def product(x,y):
    coeff=[0,0,0]
    for i in range(2):
        for j in range(2):coeff[i+j]+=x[i]*y[j]
    return ((coeff[0]+7*coeff[2])%Q,coeff[1]%Q)
def complement(x):return ((1-x[0])%Q,-x[1]%Q)
def original_cube(values,point):
    acc=(0,0)
    for index,value in enumerate(values):
        weight=(1,0)
        for axis,x in enumerate(point):
            weight=product(weight,x if (index>>(len(point)-axis-1))&1 else complement(x))
        acc=plus(acc,product(weight,value))
    return acc
def fold(values,point):
    v=list(values)
    for x in point:
        half=len(v)//2
        v=[plus(product(complement(x),v[i]),product(x,v[i+half])) for i in range(half)]
    assert len(v)==1
    return v[0]
def evaluation(data,row_log,private_log,offset,mask_row,point,large=False):
    width=2**row_log; length=2**min(row_log,private_log)
    start=offset%width if private_log<row_log else 0
    tail=point[max(0,private_log-row_log):]
    values=[(data[mask_row*width+start+i],data[(mask_row+1)*width+start+i]) for i in range(length)]
    return (fold if large else original_cube)(values,tail)
def extension(values,masks,rounds,coordinates):
    ans=list(values)
    for r,t in enumerate(coordinates):
        for j,v in enumerate(ans):
            ans[j]=plus(product(complement(t),v),product(t,masks[j] if rounds[j]==r else (0,0)))
    return ans
