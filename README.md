# SimplePower

A Garmin Edge DataField used to estimate the power output of the rider.

The power is calculated by adding the main forces acting to the bike and rider. These are:

1. Gravitational Force
   
    $$\alpha = \arctan(gr/100)$$
    
    $$F_{gr} = \sin(\alpha) \cdot m \cdot g$$
2. Aerodynamic Drag

   $$F_{air} = \frac{1}{2} \cdot C_d \cdot A \cdot \rho \cdot v^2$$
3. Acceleration

   $$F_{acc} = m \cdot a$$
4. Rolling Resistance

   $$F_{rr} = \cos(\alpha) \cdot m \cdot g \cdot C_{rr}$$

With

- $gr$ is the grade in percent
- $m$ is the system mass (rider, bike and kit)
- $g=9.81$m/s²
- $A$ is the frontal area
- $C_d$ is the drag coefficient
- $\rho$ is the air density
- $v$ is the velocity
- $a$ is the acceleration
- $C_{rr}$ is the rolling resistance coefficient
- $C_{dt}$ describes the losses in the drive train

Power required to overcome these forces is
$$F_{sum}=F_{gr}+F_{air}+F_{acc}+F_{rr}$$
$$P_{wheel}=F_{sum}\cdot v$$
$$P_{leg} = P_{wheel}/(1-C_{dt})$$

# Limitations

On the flat the power produced by the rider is mainly used to overcome the aerodynamic drag. And at the same time the aerodynamic drag is the most uncertain value in this calculation. This is mainly because aerodynamic drag is heavily influenced by wind speed/direction and the body position. Both things which vary much and are imposible to estimate from the data available at the Garmin computer.

This means the power value calculated is only useable if the aerodynamic drag plays a minor role. And this is the case only if you are riding uphill at low speed. In this case the gravitational force is the dominant force and the aerodynamic drag is only a small correction.